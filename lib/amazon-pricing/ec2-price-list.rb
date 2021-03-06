module AwsPricing
  class Ec2PriceList < PriceList
    include AwsPricing::Ec2Common

    def initialize
      super
      InstanceType.populate_lookups
      get_ec2_on_demand_instance_pricing
      get_ec2_legacy_reserved_instance_pricing
      get_ec2_reserved_instance_pricing
      fetch_ec2_ebs_pricing
    end

    protected

    # the following were verified that the URL actually works:
    # - note that mswinSQLEnterprise is not like the others (and linuxSQL* didn't work in NEW_OS_TYPES)
    # - for new OS supported (like linuxSQL*), pay attention to #get_ec2_legacy_reserved_instance_pricing
    #   to verify that pricing is available for previousGen instance types.
    @@OS_TYPES = [:linux, :mswin, :rhel, :sles, :mswinSQL, :mswinSQLWeb]
    @@NEW_OS_TYPES = [:mswinSQLEnterprise]
    @@LINUXSQL_OS_TYPES = [:linuxSQL, :linuxSQLWeb, :linuxSQLEnterprise]
    @@LEGACY_RES_TYPES = [:light, :medium, :heavy]

    def get_ec2_on_demand_instance_pricing
      (@@OS_TYPES + @@NEW_OS_TYPES + @@LINUXSQL_OS_TYPES).each do |os|
        fetch_ec2_instance_pricing(EC2_BASE_URL + "#{os}-od.min.js", :ondemand, os)
      end
      # Rinse & repeat for legacy instances
      (@@OS_TYPES + @@LINUXSQL_OS_TYPES).each do |os|
        fetch_ec2_instance_pricing(EC2_BASE_URL + "previous-generation/#{os}-od.min.js", :ondemand, os)
      end
    end

    def get_ec2_legacy_reserved_instance_pricing
      @@OS_TYPES.each do |os|
        @@LEGACY_RES_TYPES.each do |res_type|
          fetch_ec2_instance_pricing(EC2_BASE_URL + "#{os}-ri-#{res_type}.min.js", res_type, os)
          # Rinse & repeat for legacy instances (note: amazon changed URLs for legacy reserved instances)
          os_rewrite = os
          os_rewrite = "redhatlinux" if os == :rhel
          os_rewrite = "suselinux" if os == :sles
          os_rewrite = "mswinsqlstd" if os == :mswinSQL
          os_rewrite = "mswinsqlweb" if os == :mswinSQLWeb
          fetch_ec2_instance_pricing(EC2_BASE_URL + "previous-generation/#{res_type}_#{os_rewrite}.min.js", res_type, os)
        end
      end
    end

    def get_ec2_reserved_instance_pricing
      # I give up on finding a pattern so just iterating over known URLs
      page_targets = {"linux-unix" => :linux, "red-hat-enterprise-linux" => :rhel, "suse-linux" => :sles, "windows" => :mswin, 
        "windows-with-sql-server-standard" => :mswinSQL, "windows-with-sql-server-web" => :mswinSQLWeb, "windows-with-sql-server-enterprise" => :mswinSQLEnterprise,
        "linux-with-sql-server-standard" => :linuxSQL, "linux-with-sql-server-web" => :linuxSQLWeb, "linux-with-sql-server-enterprise" => :linuxSQLEnterprise,
      }
      page_targets.each_pair do |target, operating_system|
        url = "#{EC2_BASE_URL}ri-v2/#{target}-shared.min.js"
        fetch_ec2_instance_pricing_ri_v2(url, operating_system)
      end

      # I give up on finding a pattern so just iterating over known URLs
      page_targets = {"linux-unix" => :linux, "red-hat-enterprise-linux" => :rhel, "suse-linux" => :sles, "windows" => :mswin, 
        "windows-with-sql-server-standard" => :mswinSQL, "windows-with-sql-server-web" => :mswinSQLWeb, 
        "linux-with-sql-server-standard" => :linuxSQL, "linux-with-sql-server-web" => :linuxSQLWeb, "linux-with-sql-server-enterprise" => :linuxSQLEnterprise,
      }
      page_targets.each_pair do |target, operating_system|
        url = "#{EC2_BASE_URL}previous-generation/ri-v2/#{target}-shared.min.js"
        fetch_ec2_instance_pricing_ri_v2(url, operating_system)
      end
    end

    def fetch_ec2_ebs_pricing
      res_current = PriceList.fetch_url(EBS_BASE_URL + "pricing-ebs.min.js")
      res_previous = PriceList.fetch_url(EBS_BASE_URL + "pricing-ebs-previous-generation.min.js")
      res_current["config"]["regions"].each do |region_types_current|
        region_name = region_types_current["region"]
        region = get_region(region_name)
        if region.nil?
          $stderr.puts "[fetch_ec2_ebs_pricing] WARNING: unable to find region #{region_name}"
          next
        end
        region_previous = res_previous["config"]["regions"]
        region_types_previous = region_previous.select{|rp| region_name == rp["region"]}.first
        region.ebs_price = EbsPrice.new(region)
        region.ebs_price.update_from_json(region_types_current)
        region.ebs_price.update_from_json(region_types_previous)
      end
    end

  end
end
