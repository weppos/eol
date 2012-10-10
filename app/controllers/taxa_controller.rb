class TaxaController < ApplicationController

  layout 'v2/taxa'

  prepend_before_filter :redirect_back_to_http if $USE_SSL_FOR_LOGIN   # if we happen to be on an SSL page, go back to http

  before_filter :instantiate_taxon_concept, :redirect_if_superceded, :instantiate_preferred_names, :only => 'overview'
  before_filter :add_page_view_log_entry, :only => 'overview'

  def show
    if this_request_is_really_a_search
      do_the_search
      return
    end
    return redirect_to overview_taxon_path(params[:id]), :status => :moved_permanently
  end

  def overview
    TaxonConcept.preload_associations(@taxon_concept, { :published_hierarchy_entries => :hierarchy })
    @browsable_hierarchy_entries ||= @taxon_concept.published_hierarchy_entries.select{ |he| he.hierarchy.browsable? }
    @browsable_hierarchy_entries = [@selected_hierarchy_entry] if @browsable_hierarchy_entries.blank?
    @browsable_hierarchy_entries.compact!
    @hierarchies = @browsable_hierarchy_entries.collect{|he| he.hierarchy }.uniq
    
    @summary_text = @taxon_concept.overview_text_for_user(current_user)
    
    @map = @taxon_concept.data_objects_from_solr({
      :page => 1,
      :per_page => 1,
      :data_type_ids => DataType.image_type_ids,
      :data_subtype_ids => DataType.map_type_ids,
      :vetted_types => ['trusted', 'unreviewed'],
      :visibility_types => ['visible'],
      :ignore_translations => true
    })
    limit = @map.blank? ? 4 : 3
    media = promote_exemplar_image(@taxon_concept.images_from_solr(limit, @selected_hierarchy_entry, true))
    @media = @map.blank? ? media : media[0..2] + @map
    
    DataObject.preload_associations(@media, :translations , :conditions => "data_object_translations.language_id=#{current_language.id}")
    DataObject.preload_associations(@media, 
      [ :users_data_object, :license,
        { :agents_data_objects => [ { :agent => :user }, :agent_role ] },
        { :data_objects_hierarchy_entries => [ { :hierarchy_entry => [ { :name => :canonical_form }, :taxon_concept, :vetted, :visibility,
          { :hierarchy => { :resource => :content_partner } } ] }, :vetted, :visibility ] },
        { :curated_data_objects_hierarchy_entries => { :hierarchy_entry => [ :name, :taxon_concept, :vetted, :visibility ] } } ] )
    @watch_collection = logged_in? ? current_user.watch_collection : nil
    @assistive_section_header = I18n.t(:assistive_overview_header)
    @rel_canonical_href = @selected_hierarchy_entry ?
      overview_taxon_entry_url(@taxon_concept, @selected_hierarchy_entry) :
      overview_taxon_url(@taxon_concept)
    current_user.log_activity(:viewed_taxon_concept_overview, :taxon_concept_id => @taxon_concept.id)
  end

  ################
  # AJAX CALLS
  ################

  def publish_wikipedia_article
    tc = TaxonConcept.find(params[:taxon_concept_id].to_i)
    data_object = DataObject.find(params[:data_object_id].to_i)
    data_object.publish_wikipedia_article(tc)

    category_id = params[:category_id].to_i
    redirect_url = "/pages/#{tc.id}"
    redirect_url += "?category_id=#{category_id}" unless category_id.blank? || category_id == 0
    current_user.log_activity(:published_wikipedia_article, :taxon_concept_id => tc.id)
    redirect_to redirect_url
  end

  def lookup_reference
    ref = Ref.find(params[:ref_id].to_i)
    callback = params[:callback]

    if defined? $REFERENCE_PARSING_ENABLED
      raise 'Reference parsing disabled' if !$REFERENCE_PARSING_ENABLED
    else
      parameter = SiteConfigurationOption.reference_parsing_enabled
      raise 'Reference parsing disabled' unless parameter && parameter.value == 'true'
    end

    if defined? $REFERENCE_PARSER_ENDPOINT
      endpoint = $REFERENCE_PARSER_ENDPOINT
    else
      endpoint_param = SiteConfigurationOption.reference_parser_endpoint
      endpoint = endpoint_param.value
    end

    if defined? $REFERENCE_PARSER_PID
      pid = $REFERENCE_PARSER_PID
    else
      pid_param = SiteConfigurationOption.reference_parser_pid
      pid = pid_param.value
    end

    raise 'Invalid configuration' unless pid && endpoint

    url = endpoint + "?pid=#{pid}&output=json&q=#{URI.escape(ref.full_reference)}&callback=#{callback}"
    render :text => Net::HTTP.get(URI.parse(url))
  end

protected

  def controller_action_scope
    @controller_action_scope ||= @selected_hierarchy_entry ? super << :hierarchy_entry : super
  end

  def scoped_variables_for_translations
    @scoped_variables_for_translations ||= super.dup.merge({
      :preferred_common_name => @preferred_common_name.presence,
      :scientific_name => @scientific_name.presence,
      :hierarchy_provider => @selected_hierarchy_entry ? @selected_hierarchy_entry.hierarchy_label.presence : nil,
    }).freeze
  end

  def meta_title
    return @meta_title if defined?(@meta_title)
    translation_vars = scoped_variables_for_translations.dup
    translation_vars[:default] = [translation_vars[:preferred_common_name],
                                  translation_vars[:scientific_name],
                                  translation_vars[:hierarchy_provider],
                                  @assistive_section_header].compact.join(" - ")
    @meta_title = t(".meta_title#{translation_vars[:preferred_common_name] ? '_with_common_name' : ''}", translation_vars)
  end

  def meta_description
    @meta_description ||= t(".meta_description#{scoped_variables_for_translations[:preferred_common_name] ? '_with_common_name' : ''}",
                            scoped_variables_for_translations.dup)
  end

  def meta_keywords
    return @meta_keywords if defined?(@meta_keywords)
    translation_vars = scoped_variables_for_translations.dup
    keywords = [ translation_vars[:preferred_common_name],
      translation_vars[:scientific_name],
      translation_vars[:preferred_common_name] && @assistive_section_header ? "#{translation_vars[:preferred_common_name]} #{@assistive_section_header}" : nil,
      translation_vars[:scientific_name] && @assistive_section_header ? "#{translation_vars[:scientific_name]} #{@assistive_section_header}" : nil,
      translation_vars[:hierarchy_provider]
    ].uniq.compact.join(", ")
    additional_keywords = t(".meta_keywords#{translation_vars[:preferred_common_name] ? '_with_common_name' : ''}",
                            translation_vars)
    @meta_keywords = [keywords, additional_keywords.presence].compact.join(', ')
  end

  def meta_open_graph_image_url
    @meta_open_graph_image_url ||= (@taxon_concept && dato = @taxon_concept.exemplar_or_best_image_from_solr) ?
       dato.thumb_or_object('260_190', $SINGLE_DOMAIN_CONTENT_SERVER).presence : nil
  end

private

  def instantiate_taxon_concept
    tc_id = params[:taxon_concept_id] || params[:taxon_id] || params[:id]
    # we had cases of app servers not properly getting the page ID from parameters and throwing 404
    # errors instead of 500. This may cause site crawlers to think pages don't exist. So throw errors instead
    raise if tc_id.blank? || tc_id == 0
    # add params to error logging
    @taxon_concept = TaxonConcept.find(tc_id)
    unless @taxon_concept.published?
      if logged_in?
        raise EOL::Exceptions::SecurityViolation, "User with ID=#{current_user.id} does not have access to TaxonConcept with id=#{@taxon_concept.id}"
      else
        raise EOL::Exceptions::MustBeLoggedIn, "Non-authenticated user does not have access to TaxonConcept with ID=#{@taxon_concept.id}"
      end
    end

    @taxon_concept.current_user = current_user
    @selected_hierarchy_entry_id = params[:hierarchy_entry_id] || params[:entry_id]
    if @selected_hierarchy_entry_id.nil? && params[:taxon_id] && params[:id]
      @selected_hierarchy_entry_id = params[:id]
    end
    if @selected_hierarchy_entry_id
      @selected_hierarchy_entry = HierarchyEntry.find_by_id(@selected_hierarchy_entry_id) rescue nil
      if @selected_hierarchy_entry.hierarchy.browsable?
        # TODO: Eager load hierarchy entry agents?
        TaxonConcept.preload_associations(@taxon_concept, { :published_hierarchy_entries => :hierarchy })
        @browsable_hierarchy_entries = @taxon_concept.published_hierarchy_entries.select{ |he| he.hierarchy.browsable? }
      else
        @selected_hierarchy_entry = nil
      end
    end
  end

  def instantiate_preferred_names
    @preferred_common_name = @selected_hierarchy_entry ? @selected_hierarchy_entry.taxon_concept.preferred_common_name_in_language(current_language) : @taxon_concept.preferred_common_name_in_language(current_language)
    debugger if $FOO
    @scientific_name = @selected_hierarchy_entry ? @selected_hierarchy_entry.italicized_name : @taxon_concept.title_canonical_italicized
  end

  def promote_exemplar_image(data_objects)
    # TODO: a comment may be needed. If the concept is blank, why would there be images to promote?
    # we should just return
    if @taxon_concept.blank? || @taxon_concept.published_exemplar_image.blank?
      exemplar_image = data_objects[0] unless data_objects.blank?
    else
      exemplar_image = @taxon_concept.published_exemplar_image
    end
    unless exemplar_image.nil?
      data_objects.delete_if{ |d| d.guid == exemplar_image.guid }
      data_objects.unshift(exemplar_image)
    end
    data_objects
  end

  def redirect_if_superceded
    if @taxon_concept.superceded_the_requested_id?
      redirect_to url_for(:controller => params[:controller], :action => params[:action], :taxon_id => @taxon_concept.id), :status => :moved_permanently
      return false
    end
  end

  def add_page_view_log_entry
    PageViewLog.create(:user => current_user, :agent => current_user.agent, :taxon_concept => @taxon_concept)
  end

  def get_new_text_tocitem_id(category_id)
    if category_id && toc = TocItem.find_by_id(category_id)
      return category_id if toc.allow_user_text?
    end
    return 'none'
  end

  def this_request_is_really_a_search
    tc_id = params[:id].to_i
    tc_id = params[:taxon_id].to_i if tc_id == 0
    tc_id == 0
  end

  def do_the_search
    redirect_to search_path(:q => params[:id])
  end

  def is_common_names?(category_id)
    TocItem.common_names.id == category_id
  end

  def build_language_list
    current_user_copy = current_user.dup || nil
    @languages = Language.with_iso_639_1.map do |lang|
      { :label    => lang.label,
        :id       => lang.id,
        :selected => lang.id == (current_user_copy && current_user_copy.language.id) ? "selected" : nil
      }
    end
  end

  def log_action(tc, object, method)
    auto_collect(tc) # SPG asks for all curation (including names) to add the item to their watchlist.
    # NOTE - Don't pass :data_object into this; it will overwrite the value of :object_id.
    CuratorActivityLog.create(
      :user_id => current_user.id,
      :changeable_object_type => ChangeableObjectType.send(object.class.name.underscore.to_sym),
      :object_id => object.id,
      :activity => Activity.send(method),
      :taxon_concept_id => tc.id,
      :created_at => 0.seconds.from_now
    )
  end

end
