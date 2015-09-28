module Neo4j::ActiveNode::Labels
  module Indexing
    extend ActiveSupport::Concern

    module ClassMethods
      extend Forwardable

      def_delegators :declared_properties, :indexed_properties

      # Creates a Neo4j index on given property
      #
      # This can also be done on the property directly, see Neo4j::ActiveNode::Property::ClassMethods#property.
      #
      # @param [Symbol] property the property we want a Neo4j index on
      # @param [Hash] conf optional property configuration
      #
      # @example
      #   class Person
      #      include Neo4j::ActiveNode
      #      property :name
      #      index :name
      #    end
      #
      # @example with constraint
      #   class Person
      #      include Neo4j::ActiveNode
      #      property :name
      #
      #      # below is same as: index :name, index: :exact, constraint: {type: :unique}
      #      index :name, constraint: {type: :unique}
      #    end
      def index(property)
        Neo4j::Session.on_next_session_available do |_|
          drop_constraint(property, type: :unique) if Neo4j::Label.constraint?(mapped_label_name, property)
          declared_properties[property].index! unless id_property_name == property
          _index(property)
        end
        indexed_properties.push property unless indexed_properties.include? property
      end

      # Creates a neo4j constraint on this class for given property
      #
      # @example
      #   Person.constraint :name, type: :unique
      #
      def constraint(property, constraints)
        Neo4j::Session.on_next_session_available do |session|
          unless Neo4j::Label.constraint?(mapped_label_name, property)
            label = Neo4j::Label.create(mapped_label_name)
            drop_index(property, label) if index?(property)
            declared_properties[property].constraint! unless id_property_name == property
            label.create_constraint(property, constraints, session)
          end
        end
      end

      # @param [Symbol] property The name of the property index to be dropped
      # @param [Neo4j::Label] label An instance of label from Neo4j::Core
      def drop_index(property, label = nil)
        declared_properties[property].unindex! if declared_properties[property]
        label_obj = label || Neo4j::Label.create(mapped_label_name)
        label_obj.drop_index(property)
      end

      # @param [Symbol] property The name of the property constraint to be dropped
      # @param [Hash] constraint The constraint type to be dropped.
      def drop_constraint(property, constraint = {type: :unique})
        Neo4j::Session.on_next_session_available do |session|
          declared_properties[property].unconstraint! if declared_properties[property]
          label = Neo4j::Label.create(mapped_label_name)
          label.drop_constraint(property, constraint, session)
        end
      end

      def index?(index_def)
        mapped_label.indexes[:property_keys].include?([index_def])
      end

      protected

      def _index(property)
        mapped_labels.each do |label|
          # make sure the property is not indexed twice
          existing = label.indexes[:property_keys]
          label.create_index(property) unless existing.flatten.include?(property)
        end
      end
    end
  end
end