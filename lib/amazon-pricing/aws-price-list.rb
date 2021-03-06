#--
# Amazon Web Services Pricing Ruby library
#
# Ruby Gem Name::  amazon-pricing
# Author::    Joe Kinsella (mailto:joe.kinsella@gmail.com)
# Copyright:: Copyright (c) 2011-2013 CloudHealth
# License::   Distributes under the same terms as Ruby
# Home::      http://github.com/CloudHealth/amazon-pricing
#++
module AwsPricing

  # PriceList provides the primary interface for retrieving AWS pricing.
  # Upon instantiating a PriceList object, all the corresponding pricing
  # information will be retrieved from Amazon via currently undocumented
  # json APIs.
  class PriceList
    attr_accessor :regions
    RETRY_LIMIT = 3

    def initialize()
      @_regions = {}

      # Creating regions upfront since different json files all use different naming conventions. No more ad-hoc creation.
      regions = ["eu-west-1", "sa-east-1", "us-east-1", "ap-northeast-1", "us-west-2", "us-west-1", "ap-southeast-1", "ap-southeast-2",
		 "eu-central-1", "us-gov-west-1", "us-gov-east-1", "ap-northeast-2", "ap-south-1", "us-east-2", "ca-central-1", "eu-west-2", "eu-west-3",
     "ap-northeast-3", "eu-north-1", "ap-east-1"]

      regions.each do |name|
        @_regions[name] = Region.new(name)
      end
    end

    # EBS now reports regions correctly but all else still has the old format - so we need to handle both
    # region mapping and non-mapping
    def get_region(name)
      #@_regions[@@Region_Lookup[name] || name]
      @_regions[convert_region(name)]
    end

    def regions
      @_regions.values
    end

    def get_instance_types
      instance_types = []
      @_regions.each do |region|
        region.ec2_instance_types.each do |instance_type|
          instance_types << instance_type
        end
      end
      instance_types
    end

    def get_instance_type(region_name, api_name)
      region = get_region(region_name)
      raise "Region #{region_name} not found" if region.nil?
      region.get_instance_type(api_name)
    end

    def self.fetch_url(url)
      # AWS appears to have started throttling URL accesses, so we now have to retry
      begin
        retry_count ||= 0
        #$stdout.puts "[#{__method__}] url:#{url}"
        uri = URI.parse(url)
        page = Net::HTTP.get_response(uri)
      rescue StandardError => e  #Exception => e
        $stderr.puts "Exception:#{e} retry-#{retry_count} Failed to fetch: #{url}"
        sleep 5 # appears to get past (AWS) throttling
        retry if (retry_count += 1) <= RETRY_LIMIT
      end

      # Now that AWS switched from json to jsonp, remove first/last lines
      body = page.body.gsub("callback(", "").reverse.sub(")", "").reverse
      if body.split("\n").last == ";"
        # Now remove one more line (rds is returning ";", ec2 empty line)
        body = body.reverse.sub(";", "").reverse
      elsif body[-1] == ";"
        body.chop!
      end

      begin
        JSON.parse(body)
      rescue JSON::ParserError
        # Handle "json" with keys that are not quoted
        # When we get {foo: "1"} instead of {"foo": "1"}
        # http://stackoverflow.com/questions/2060356/parsing-json-without-quoted-keys
        JSON.parse(body.gsub(/(\w+)\s*:/, '"\1":'))
      end
    rescue Exception => e
      $stderr.puts "Exception:#{e} Failed to parse: #{url} #{e.backtrace}"
      raise e
    end

    protected

    attr_accessor :_regions

    #def add_region(region)
    #  @_regions[region.name] = region
    #end

    #def find_or_create_region(name)
    #  region = get_region(name)
    #  if region.nil?
    #    # We must use standard names
    #    region = Region.new(name)
    #    add_region(region)
    #  end
    #  region
    #end

    EC2_BASE_URL         = "http://a0.awsstatic.com/pricing/1/ec2/"
    EBS_BASE_URL         = "http://a0.awsstatic.com/pricing/1/ebs/"
    RDS_BASE_URL         = "http://a0.awsstatic.com/pricing/1/rds/"
    ELASTICACHE_BASE_URL = "http://a0.awsstatic.com/pricing/1/elasticache/"

    DI_OD_BASE_URL = "http://a0.awsstatic.com/pricing/1/dedicated-instances/"
    DH_OD_BASE_URL = "http://a0.awsstatic.com/pricing/1/dedicated-hosts/"
    RESERVED_DI_BASE_URL = "http://a0.awsstatic.com/pricing/1/ec2/ri-v2/"
    RESERVED_DI_PREV_GEN_BASE_URL = "http://a0.awsstatic.com/pricing/1/ec2/previous-generation/ri-v2/"

    def convert_region(name)
      case name
      when "us-east"
        "us-east-1"
      when "us-west"
        "us-west-1"
      when "eu-ireland"
        "eu-west-1"
      when "apac-sin"
        "ap-southeast-1"
      when "apac-syd"
        "ap-southeast-2"
      when "apac-tokyo"
        "ap-northeast-1"
      when "eu-frankfurt"
        "eu-central-1"
      else
        name
      end
    end

  end


end
