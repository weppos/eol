# To allow administartors to add / remove the tags that always 
# show up as suggested (static public tags)
class Administrator::TagSuggestionController < AdminController

  layout 'left_menu'

  before_filter :set_layout_variables

  access_control Privilege.comments_and_tags
  
  # GET /administrator/tag_suggestions
  def index
    @admin_header="Tag Suggestions"
    @tags = DataObjectTag.paginate_all_by_is_public true, :page => params[:page], :per_page => 10
  end

  # POST /administrator/tag_suggestions
  def create
    tag = DataObjectTag.find_or_create_by_key_and_value params[:tag][:key], params[:tag][:value]
    tag.update_attribute :is_public, true
    redirect_to :action => :index
  end

  # DELETE /administartor/tag_suggestions
  def destroy
    tag = DataObjectTag.find params[:id]
    if tag
      if tag.usage_count == 0
        tag.destroy
      else
        tag.update_attribute :is_public, false
      end
    end
    redirect_to :action => :index
  end

private

  def set_layout_variables
    @page_title = $ADMIN_CONSOLE_TITLE
    @navigation_partial = '/admin/navigation'
  end

end
