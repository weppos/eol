require File.dirname(__FILE__) + '/../spec_helper'

def curator_for_taxon_id(id)
  User.find(:all).each do |user|
    return user if user.can_curate_taxon_id?(id)
  end
end

def create_curator_for_taxon_concept(tc)
  Factory(:curator, :username => 'test_curator',
          :password => 'test_password',
          :curator_hierarchy_entry => HierarchyEntry.gen(:taxon_concept => tc))
end

describe 'Curation' do
  scenario :foundation

  before :each do
    @taxon_concept = build_taxon_concept()
    @default_page  = request("/pages/#{@taxon_concept.id}")
  end

  it 'should not show curation button when not logged in' do
    @default_page.body.should_not have_tag('div#large-image-curator-button')
  end

  it 'should show curation button when logged in as curator' do
    curator = create_curator_for_taxon_concept(@taxon_concept)

    login_as( curator ).should redirect_to('/index')

    request("/pages/#{@taxon_concept.id}").body.should have_tag('div#large-image-curator-button')
  end

  it 'should expire taxon from cache' do
    curator = create_curator_for_taxon_concept(@taxon_concept)

    login_as( curator ).should redirect_to('/index')

    old_cache_val = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true

    ActionController::Base.cache_store.should_receive(:delete).any_number_of_times

    request("/data_objects/#{@taxon_concept.images[0].id}/curate", :params => {
            '_method' => 'put',
            'curator_activity_id' => CuratorActivity.disapprove!.id})

    Rails.cache.clear
    ActionController::Base.perform_caching = old_cache_val
  end

  # --- page citation ---
  
  it 'should confirm that the page doesn\'t have the citation if there is no active curator for the taxon' do
    LastCuratedDate.delete_all
    the_page = request("/pages/#{@taxon_concept.id}")
    the_page.body.should_not have_tag('div#number-of-curators')
    the_page.body.should_not have_tag('div#page-citation')
  end
    
  it 'should say the page has citation (both lines)' do
    @default_page.body.should have_tag('div#number-of-curators')
    @default_page.body.should have_tag('div#page-citation')
  end

  it 'should change the number of curators if another curator curates an image' do
    num_curators = @taxon_concept.acting_curators.length
    @default_page.body.should have_tag('div#number-of-curators', /#{num_curators}/)
    user = Factory(:curator, :curator_hierarchy_entry => @taxon_concept.entry)
    @taxon_concept.images.last.curator_activity_flag user, @taxon_concept.id
    @taxon_concept.acting_curators.length.should == num_curators + 1
    request("/pages/#{@taxon_concept.id}").body.should have_tag('div#number-of-curators', /#{num_curators+1}/)
  end
              
  it 'should change the number of curators if another curator curates a text object' do
    num_curators = @taxon_concept.acting_curators.length
    @default_page.body.should have_tag('div#number-of-curators', /#{num_curators}/)
    user = Factory(:curator, :curator_hierarchy_entry => @taxon_concept.entry)
    @taxon_concept.overview.first.curator_activity_flag user, @taxon_concept.id
    @taxon_concept.acting_curators.length.should == num_curators + 1
    request("/pages/#{@taxon_concept.id}").body.should have_tag('div#number-of-curators', /#{num_curators+1}/)
  end
              
  it 'should have a link from N curators to the citation' do
    @default_page.body.should have_tag('a[href*=?]', /#citation/) do
      with_tag('div#number-of-curators')
    end
  end
  
  it 'should have a link from name of curator to account page' do
    @default_page.body.should have_tag('div#page-citation') do
      with_tag('a[href*=?]', /\/account\/show\/#{@taxon_concept.acting_curators.first.id}/)
    end
  end

end
