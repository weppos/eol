class UserAddedDataController < ApplicationController

  layout 'v2/basic'

  skip_before_filter :original_request_params, :global_warning, :set_locale, :check_user_agreed_with_terms, :only => :autocomplete_known_uri_uri

  # Doesn't seem to work unless it's here as WELL as taxon/data.
  autocomplete :known_uri, :uri
  autocomplete :translated_known_uri, :name

  # POST /user_added_data
  def create
    delete_empty_metadata
    convert_fields_to_uri
    # TODO - fix this later:
    type = params[:user_added_data].delete(:subject_type)
    raise "I don't know anything about #{type}, can't find one." unless type == 'TaxonConcept'
    subject = TaxonConcept.find(params[:user_added_data].delete(:subject_id))
    @user_added_data = UserAddedData.new(params[:user_added_data].reverse_merge(user: current_user,
                                                                                subject: subject))
    if @user_added_data.save
      flash[:notice] = I18n.t('user_added_data.create_successful')
    else
      # NOTE - we can't just use validation messages quite yet, since it's created in another controller. :\
      if @user_added_data.errors.any?
        flash[:error] = I18n.t('user_added_data.create_failed',
                               errors: @user_added_data.errors.full_messages.to_sentence)
      end
    end
    redirect_to taxon_data_path(@user_added_data.taxon_concept_id)
  end

  # GET /user_added_data/:id/edit
  def edit
    @user_added_data = UserAddedData.find(params[:id])
    unless current_user.can_update?(@user_added_data)
      raise EOL::Exceptions::SecurityViolation,
        "User with ID=#{current_user.id} does not have edit access to UserAddedData with ID=#{@user_added_data.id}"
    end
  end

  # PUT /user_added_data/:id
  def update
    delete_empty_metadata
    @user_added_data = UserAddedData.find(params[:id])
    unless current_user.can_update?(@user_added_data)
      raise EOL::Exceptions::SecurityViolation,
        "User with ID=#{current_user.id} does not have edit access to UserAddedData with ID=#{@user_added_data.id}"
    end
    if @user_added_data.update_attributes(params[:user_added_data])
      flash[:notice] = I18n.t('user_added_data.update_successful')
    else
      flash[:error] = I18n.t('user_added_data.update_failed',
                             errors: @user_added_data.errors.full_messages.to_sentence)
      render :edit
      return
    end
    redirect_to taxon_data_path(@user_added_data.subject)
  end

  # DELETE /user_added_data/:id
  def destroy
    user_added_data = UserAddedData.find(params[:id])
    raise EOL::Exceptions::SecurityViolation,
      "User with ID=#{current_user.id} does not have edit access to UserAddedData with ID=#{@user_added_data.id}" unless current_user.can_delete?(user_added_data)
    user_added_data.update_attributes({ :deleted_at => Time.now })
    flash[:notice] = I18n.t('user_added_data.delete_successful')
    redirect_to taxon_data_path(user_added_data.taxon_concept_id)
  end

  private

  # Not just "empty" but also deafult values that we consider "empty".
  def delete_empty_metadata
    params[:user_added_data][:user_added_data_metadata_attributes].delete_if do |k,v|
      if v[:id].blank? && v[:predicate].blank? && v[:object].blank?
        true
      else
        case v[:predicate]
        when UserAddedDataMetadata::SUPPLIER_URI
          v[:object] == current_user.full_name # No need to add this; it's in the DB already.
        when UserAddedDataMetadata::SOURCE_URI
          v[:object] == I18n.t('user_added_data.source_field_helper')
        when UserAddedDataMetadata::LICENSE_URI
          v[:object] == I18n.t(:license_none)
        when I18n.t('user_added_data.new_field')
          true # They didn't add (or at least name) this one, just remove it.
        else
          false
        end
      end
    end
  end

  def convert_fields_to_uri
    convert_field_to_uri(params[:user_added_data], :predicate)
    convert_field_to_uri(params[:user_added_data], :object)
    params[:user_added_data][:user_added_data_metadata_attributes].each do |index, meta|
      convert_field_to_uri(meta, :predicate)
      convert_field_to_uri(meta, :object)
    end
  end

  # NOTE - just passing in the field wasn't working (thought it would be by ref, but I guess not), so we need the hash and the key:
  def convert_field_to_uri(hash, key)
    return unless hash[key]
    converted = convert_to_uri(hash[key])
    # They want to create a new EOL-based URI:
    if converted.blank?
      hash[key] = KnownUri.custom(hash[key], current_language).uri unless key != :object # Not for values.
    else
      hash[key] = converted
    end
  end

  # NOTE that this only takes the first one it finds.
  def convert_to_uri(name)
    return nil unless TranslatedKnownUri.exists?(name: name, language_id: current_language.id)
    turi = TranslatedKnownUri.where(name: name, language_id: current_language.id).first
    return nil unless turi.known_uri && ! turi.known_uri.uri.blank?
    uri = turi.known_uri.uri
    session[:rec_uris] ||= []
    session[:rec_uris].unshift(uri)
    session[:rec_uris] = session[:rec_uris].uniq[0..7]
    uri
  end

end
