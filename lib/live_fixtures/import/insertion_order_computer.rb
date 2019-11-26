class LiveFixtures::Import
  # :nodoc:
  class InsertionOrderComputer
    # :nodoc:
    class Node
      attr_reader :path
      attr_reader :class_name
      attr_reader :klass

      # The classes this node depends on
      attr_reader :dependencies

      def initialize(path, class_name, klass)
        @path = path
        @class_name = class_name
        @klass = klass
        @dependencies = Set.new
      end
    end

    def self.compute(table_names, class_names = {}, polymorphic_associations = {})
      new(table_names, class_names, polymorphic_associations).compute
    end

    def initialize(table_names, class_names = {}, polymorphic_associations = {})
      @table_names = table_names
      @class_names = class_names
      @polymorphic_associations = polymorphic_associations
    end

    def compute
      nodes = build_nodes
      compute_insert_order(nodes)
    end

    private

    # Builds an Array of Nodes, each containing dependencies to other nodes
    # using their class names.
    def build_nodes
      # Create a Hash[Class => Node] for each table/class
      nodes = {}
      @table_names.each do |path|
        table_name = path.tr "/", "_"
        class_name = @class_names[table_name.to_sym] || table_name.classify
        klass = class_name.constantize
        nodes[klass] = Node.new(path, class_name, klass)
      end

      # First iniitalize dependencies from polymorphic associations that we
      # explicitly found in the yaml files.
      @polymorphic_associations.each do |klass, associations|
        associations.each do |association|
          node = nodes[klass]
          next unless node
          next unless nodes.key?(association)

          node.dependencies << association
        end
      end

      # Compute dependencies between nodes/classes by reflecting on their
      # ActiveRecord associations.
      nodes.each do |_, node|
        klass = node.klass
        klass.reflect_on_all_associations.each do |assoc|
          # We can't handle polymorphic associations, but the concrete types
          # should have been deduced from the yaml files contents
          next if assoc.polymorphic?

          # Don't add a dependency if the class is not in the given table names
          next unless nodes.key?(assoc.klass)

          # A class might depend on itself, but we don't add it as a dependency
          # because otherwise we'll never make it (the class can probably be created
          # just fine and these dependencies are optional/nilable)
          next if klass == assoc.klass

          case assoc.macro
          when :belongs_to
            node.dependencies << assoc.klass
          when :has_one, :has_many
            # Skip `through` association becuase it will be already computed
            # for the related `has_one`/`has_many` association
            next if assoc.options[:through]

            nodes[assoc.klass].dependencies << klass
          end
        end
      end

      # Finally sort all values by name for consistent results
      nodes.values.sort_by { |node| node.klass.name }
    end

    def compute_insert_order(nodes)
      insert_order = []

      until nodes.empty?
        # Pick a node that has no dependencies
        free_node = nodes.find { |node| node.dependencies.empty? }

        if free_node.nil?
          msg = "Can't compute an insert order.\n\n"
          msg << "These models seem to depend on each other:\n"
          nodes.each do |node|
            msg << "  #{node.klass.name}\n"
            msg << "   - depends on: #{node.dependencies.map(&:name).join(", ")}\n"
          end
          raise msg
        end

        insert_order << free_node.path

        # Delete this node from the other nodes' dependencies
        nodes.each do |node|
          node.dependencies.delete(free_node.klass)
        end

        # And delete this node because we are done with it
        nodes.delete(free_node)
      end

      insert_order
    end
  end
end
