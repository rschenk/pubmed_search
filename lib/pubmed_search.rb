require 'set'
require 'open-uri'

require 'rubygems'
require 'nokogiri'
require 'simple_uri_template'   # sudo gem install rschenk-simple_uri_template


class PubmedSearch
  # List of Pubmed IDs returned by your search
  attr_accessor :pmids
  
  # The Count field returned by your search. If pmids < count, then you need to look at your retmax or try load_all_pmids
  attr_accessor :count
  
  # See exploded_mesh_terms for a description.
  attr_accessor :exploded_mesh_terms
  
  # The PhraseNotFound elements returned by your search
  attr_accessor :phrases_not_found
  
  WAIT_TIME = 1 # seconds
  DEFAULT_OPTIONS = {:retmax => 100000,
                     :retstart => 0,
                     :tool => 'ruby-pubmed_search',
                     :email => '',
                     :load_all_pmids => false }
                     
  @uri_template = SimpleURITemplate.new('http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool={tool}&email={email}&retmax={retmax}&retstart={retstart}&term={term}')
  
  class << self
    # Performs a search to PubMed via eUtils with the given term +String+, and returns a +PubmedSearch+ object modeling the response.
    #
    # Accepts a +Hash+ of options. Valid options are 
    # * :retmax - Defaults to 100,000 which is the largest retmax that PubMed will honor.
    # * :retstart - Defaults to 0. Set higher if you need to page through results. You shouldn't need to do that manually, because of the +load_all_pmids+ option
    # * :tool - Defaults to 'ruby-pubmed_search', set to the name of your tool per EUtils parameters specs
    # * :email - Defaults to '', set to your email address per EUtils parameters specs
    # * :load_all_pmids - Defaults to +false+. If this is set +true+, then search will continue sending eSearches with an increasing retstart until the list of pmids == count. For instance, an eSearch for "Mus musculus" will return ~951134 results, but the highest retmax allowable is 100000. With +load_all_pmids+ set +true+, search will automatically perform 10 eSearches and return the entire list of pmids in one go.
    def search(term, options={})
      options = DEFAULT_OPTIONS.merge(options)
    
      results = do_search(new, term, options)
    
      if options[:load_all_pmids]
        # Send off subsequent requests to load all the PMIDs, add them to the results
        (options[:retmax]..results.count).step(options[:retmax]) do |step|
          do_search(results, term, options.merge({:retstart => step}))
        end 
      end
    
      results
    end
    
    # As of May 2009, PubMed requires a 300ms pause between eUtils calls. It used to be 3 seconds.
    # PubmedSearch pauses for 1 second just to be on the safe side.
    def wait
      sleep WAIT_TIME unless @skip_wait
    end
    
    # Setting this to true will prevent PubmedSearch from pausing before sending requests to PubMed. This is a fantastic way to get yourself banned from eUtils.
    #
    # I only use this for testing.
    def skip_wait=(setting)
      @skip_wait = setting
    end
    
    private
    
    # Performs the HTTP request and parses the response
    def do_search(results, term, options)
      wait
      
      esearch_url = @uri_template.expand(options.merge({:term => term}))
      doc = Nokogiri::XML( open esearch_url )

      results.count = doc.xpath('/eSearchResult/Count').first.content.to_i
      
      doc.xpath('/eSearchResult/IdList/Id').each {|n| results.pmids << n.content.to_i}
            
      doc.xpath('/eSearchResult/TranslationStack/TermSet/Term').each do |n|
        if n.content =~ /"(.*)"\[MeSH Terms\]/
          results.exploded_mesh_terms << $1
        end
      end
      
      doc.xpath('/eSearchResult/ErrorList/PhraseNotFound').each {|n| results.phrases_not_found << n.content }

      results
    end
  end
  
  
  # Get the list of Pubmed IDs returned by this esearch as an +Array+ of +Numbers+
  def pmids 
    @pmids ||= []
  end
  
  # Get the list of MeSH terms that PubMed exploded. 
  # For more information on MeSH term explosion, see http://www.pubmedcentral.nih.gov/articlerender.fcgi?artid=2651214#id443777
  def exploded_mesh_terms
    @exploded_mesh_terms ||= Set.new
  end
  
  # Get the list of PhraseNotFound terms returned by your search
  def phrases_not_found
    @phrases_not_found ||= Set.new
  end
  
end