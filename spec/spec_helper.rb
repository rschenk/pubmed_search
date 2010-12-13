require 'rubygems'
require 'rspec'
require 'uri'
require 'fakeweb'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'pubmed_search'



Spec::Runner.configure do |config|
  
end

FakeWeb.allow_net_connect = false

def fake_esearch_response(search_term, options={})
  file = options[:file] || search_term.downcase.gsub(/\W/, '_')
  FakeWeb.register_uri(:any, "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&tool=ruby-pubmed_search&email=&retmax=100000&retstart=0&term=#{URI.escape search_term}",
                       :body => File.dirname(__FILE__) + "/responses/#{file}.xml")
end


class OnlyInclude
  def initialize(entries)
    @expected_entries = entries
  end
  
  def matches?(array)
    @array = array
    @array.sort == @expected_entries.sort
  end
  
  def description
    "only include"
  end
  
  def failure_message
    if @expected_entries.length != @array.length
      "expected to have #{@expected_entries.length} entries, but had #{@array.length}: #{@array.inspect}"
    else
      "expected #{@array.inspect} to include #{(@expected_entries - @array).inspect}"
    end
  end
  
  def negative_failure_message
    "#{@array.inspect} expected to include other entries"
  end
end

def only_include(*args)
  OnlyInclude.new args
end