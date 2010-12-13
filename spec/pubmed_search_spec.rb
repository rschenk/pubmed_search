require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'benchmark'

fake_esearch_response "Mus musculus"
fake_esearch_response "biodiversity informatics"
fake_esearch_response "Bangana tonkinensis cranksection"

describe PubmedSearch do
  before(:each) do
    PubmedSearch.skip_wait = true
  end
  
  it "should have attributes count, pmids, exploded_mesh_terms, and phrases_not_found" do
    result = PubmedSearch.new
    result.should respond_to :count
    result.should respond_to :pmids
    result.should respond_to :exploded_mesh_terms
    result.should respond_to :phrases_not_found
  end
  
  describe "::search" do
    it "should pause before sending a subsequent request to eUtils" do
      PubmedSearch.skip_wait = false
      Benchmark.realtime{ PubmedSearch.search "biodiversity informatics" }.should > PubmedSearch::WAIT_TIME
    end
    
    it "should build a PubmedSearch object for the results" do
      result = PubmedSearch.search("biodiversity informatics")
      result.should be_an_instance_of PubmedSearch
      
      result.count.should == result.pmids.length
      
      result.pmids.should include 19129210, 18784790, 18483570
            
      result.exploded_mesh_terms.should only_include 'biodiversity', 'informatics'
      
      result.phrases_not_found.should be_empty
    end
    
    it "should allow the user to specify retmax" do
      FakeWeb.allow_net_connect = true
      result = PubmedSearch.search "Mr T", :retmax => 5
      result.pmids.length.should == 5
      FakeWeb.allow_net_connect = false
    end
    
    it "should allow the user to specify the name of their tool" do
      FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ligercat&email=&retmax=100000&retstart=0&term=e%20coli",      :body => File.dirname(__FILE__) + '/responses/e_coli_0.xml')
      PubmedSearch.search "e coli", :tool => 'ligercat' # note "tool=ligercat" in above URL. Fakeweb will complain and fail spec if necessary
    end
    
    it "should allow the user to specify their email address" do
      FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ruby-pubmed_search&email=someone@someplace.edu&retmax=100000&retstart=0&term=e%20coli",      :body => File.dirname(__FILE__) + '/responses/e_coli_0.xml')
      PubmedSearch.search "e coli", :email => 'someone@someplace.edu' # note "email=someone@someplace.edu" in above URL. Fakeweb will complain and fail spec if necessary
    end
    
    it "should allow multiple requests to NLM if Count > Retmax if desired" do
      FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ruby-pubmed_search&email=&retmax=100000&retstart=0&term=e%20coli",      :body => File.dirname(__FILE__) + '/responses/e_coli_0.xml')
      FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ruby-pubmed_search&email=&retmax=100000&retstart=100000&term=e%20coli", :body => File.dirname(__FILE__) + '/responses/e_coli_1.xml')
      FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ruby-pubmed_search&email=&retmax=100000&retstart=200000&term=e%20coli", :body => File.dirname(__FILE__) + '/responses/e_coli_2.xml')
            
      result = PubmedSearch.search("e coli", :load_all_pmids => true)
      
      result.pmids.length.should == result.count
      
      result.pmids.should include 19464251, 9737856, 6319486 # One PMID from each of the three e_coli_n.xml files
      
      result.exploded_mesh_terms.should only_include 'escherichia coli'
    end
    
    it "should record any PhraseNotFound elements" do
      result = PubmedSearch.search "Bangana tonkinensis cranksection"
      
      result.phrases_not_found.should only_include 'Bangana', 'cranksection'
    end
  end
  
end