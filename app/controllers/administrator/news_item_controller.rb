class Administrator::NewsItemController < AdminController

  layout 'left_menu'

  before_filter :set_layout_variables

  helper :resources

  access_control Privilege.news_items
  
  def index
    @page_title = 'News Items'
    @term_search_string=params[:term_search_string] || ''
    search_string_parameter='%' + @term_search_string + '%' 
    @news_items=NewsItem.paginate(:conditions=>['body like ?',search_string_parameter],:order=>'display_date desc',:page => params[:page])
    @news_items_count=NewsItem.count(:conditions=>['body like ?',search_string_parameter])
  end

  def new
    @page_title = 'New News Item'
    store_location(referred_url) if request.get?    
    @news_item = NewsItem.new
  end

  def edit
    @page_title = 'Edit News Item'
    store_location(referred_url) if request.get?            
    @news_item = NewsItem.find(params[:id])
  end

  def create
    @news_item = NewsItem.new(params[:news_item])
    if @news_item.save
      flash[:notice] = 'The news item was successfully created.'
      expire_cache('Home')
      redirect_back_or_default(url_for(:action=>'index'))
    else
      render :action => 'new' 
    end
  end

  def update
    @news_item = NewsItem.find(params[:id])
    if @news_item.update_attributes(params[:news_item])
      flash[:notice] = 'The news item was successfully updated.'
      expire_cache('Home')
      redirect_back_or_default(url_for(:action=>'index'))
    else
      render :action => 'edit' 
    end
  end


  def destroy
    (redirect_to referred_url;return) unless request.method == :delete
    @news_item = NewsItem.find(params[:id])
    @news_item.destroy
    expire_cache('Home')
    redirect_to referred_url
  end

private

  def set_layout_variables
    @page_title = $ADMIN_CONSOLE_TITLE
    @navigation_partial = '/admin/navigation'
  end

end
