module EOL
  module Api
    module Collections
      class V1_0 < EOL::Api::MethodVersion
        VERSION = '1.0'
        BRIEF_DESCRIPTION = I18n.t(:returns_all_metadata_about_a_particular_collection)
        DESCRIPTION = I18n.t(:api_docs_collections_description)
        PARAMETERS =
          [
            EOL::Api::DocumentationParameter.new(
              :name => 'id',
              :type => Integer,
              :required => true,
              :test_value => (Collection.where(:name => 'EOL Group on Flickr').first || Collection.last).id ),
            EOL::Api::DocumentationParameter.new(
              :name => 'page',
              :type => Integer,
              :default => 1 ),
            EOL::Api::DocumentationParameter.new(
              :name => 'per_page',
              :type => Integer,
              :values => (0..500),
              :default => 50 ),
            EOL::Api::DocumentationParameter.new(
              :name => 'filter',
              :type => String,
              :values => [ 'articles', 'collections', 'communities', 'images', 'sounds', 'taxa', 'users', 'video' ] ),
            EOL::Api::DocumentationParameter.new(
              :name => 'sort_by',
              :type => String,
              :values => SortStyle.all.map{ |ss| ss.name.downcase.gsub(' ', '_') rescue nil }.compact,
              :default => SortStyle.newest.name.downcase.gsub(' ', '_') ),
            EOL::Api::DocumentationParameter.new(
              :name => 'sort_field',
              :type => String,
              :notes => I18n.t('collection_api_sort_field_notes') )
          ]

        def self.call(params={})
          validate_and_normalize_input_parameters!(params)
          if params[:sort_by].class == String && ss = SortStyle.find_by_translated(:name, params[:sort_by].titleize)
            params[:sort_by] = ss
          else
            params[:sort_by] = collection.default_sort_style
          end

          begin
            collection = Collection.find(params[:id], :include => [ :sort_style ])
          rescue
            raise EOL::Exceptions::ApiException.new("Unknown collection id \"#{params[:id]}\"")
          end

          prepare_hash(collection, params)
        end

        def self.prepare_hash(collection, params={})
          facet_counts = EOL::Solr::CollectionItems.get_facet_counts(collection.id)
          collection_results = collection.items_from_solr(:facet_type => params[:filter], :page => params[:page], :per_page => params[:per_page],
            :sort_by => params[:sort_by], :view_style => ViewStyle.list, :sort_field => params[:sort_field])
          collection_items = collection_results.map { |i| i['instance'] }
          CollectionItem.preload_associations(collection_items, :refs)

          return_hash = {}
          return_hash['name'] = collection.name
          return_hash['description'] = collection.description
          return_hash['logo_url'] = collection.logo_cache_url.blank? ? nil : collection.logo_url
          return_hash['created'] = collection.created_at
          return_hash['modified'] = collection.updated_at
          return_hash['total_items'] = collection_results.total_entries

          return_hash['item_types'] = []
          ['TaxonConcept', 'Text', 'Video', 'Image', 'Sound', 'Community', 'User', 'Collection'].each do |facet|
            return_hash['item_types'] << { 'item_type' => facet, 'item_count' => facet_counts[facet] || 0 }
          end

          return_hash['collection_items'] = []
          collection_results.each do |r|
            ci = r['instance']
            next if ci.nil?
            item_hash = {
              'name' => r['title'],
              'object_type' => ci.object_type,
              'object_id' => ci.object_id,
              'title' => ci.name,
              'created' => ci.created_at,
              'updated' => ci.updated_at,
              'annotation' => ci.annotation,
              'sort_field' => ci.sort_field
            }

            if collection.show_references?
              item_hash['references'] = []
              ci.refs.each do |ref|
                item_hash['references'] << { 'reference' => ref.full_reference }
              end
            end

            case ci.object_type
            when 'TaxonConcept'
              item_hash['richness_score'] = r['richness_score']
              # item_hash['taxonRank'] = ci.object.entry.rank.label.firstcap unless ci.object.entry.rank.nil?
            when 'DataObject'
              item_hash['data_rating'] = r['data_rating']
              item_hash['object_guid'] = ci.object.guid
              item_hash['object_type'] = ci.object.data_type.simple_type
              if ci.object.is_image?
                item_hash['source'] = ci.object.thumb_or_object(:orig)
              end
            end
            return_hash['collection_items'] << item_hash
          end
          return return_hash
        end
      end
    end
  end
end
