module EOL
  module Api
    module Hierarchies
      class V1_0 < EOL::Api::MethodVersion
        VERSION = '1.0'
        BRIEF_DESCRIPTION = I18n.t(:method_to_get_metadata_about_the_hierarchy)
        DESCRIPTION = I18n.t('hierarchies_description')
        PARAMETERS =
          [
            EOL::Api::DocumentationParameter.new(
              :name => 'id',
              :type => Integer,
              :required => true,
              :test_value => Hierarchy.default.id )
          ]

        def self.call(params={})
          validate_and_normalize_input_parameters!(params)
          begin
            hierarchy = Hierarchy.find(params[:id])
            Hierarchy.preload_associations(hierarchy, { :kingdoms => [ :rank, :name ] })
          rescue
            raise EOL::Exceptions::ApiException.new("Unknown hierarchy id \"#{params[:id]}\"")
          end
          raise EOL::Exceptions::ApiException.new("Hierarchy #{id} is currently inaccessible through the API") unless hierarchy.browsable?
          prepare_hash(hierarchy)
        end

        def self.prepare_hash(hierarchy, params={})
          return_hash = {}
          return_hash['title'] = hierarchy.label
          return_hash['contributor'] = hierarchy.agent.full_name
          return_hash['dateSubmitted'] = hierarchy.indexed_on.mysql_timestamp
          return_hash['source'] = hierarchy.url

          return_hash['roots'] = []
          hierarchy.kingdoms.each do |root|
            root_hash = {}
            root_hash['sourceIdentifier'] = root.identifier unless root.identifier.blank?
            root_hash['taxonID'] = root.id
            root_hash['parentNameUsageID'] = root.parent_id
            root_hash['taxonConceptID'] = root.taxon_concept_id
            root_hash['scientificName'] = root.name.string.firstcap
            root_hash['taxonRank'] = root.rank.label unless root.rank_id == 0 || root.rank.blank?
            return_hash['roots'] << root_hash
          end
          return return_hash
        end

      end
    end
  end
end
