#!/usr/local/bin/ruby

require 'fluent/input'

module Fluent

  class QNDKempRestInput < Input
    Fluent::Plugin.register_input('qnd_kemp_rest', self)

    def initialize
      super
      require_relative 'kemp_lib'
    end

#improvements, we must be able to differentiate intervals for data collection based on type
#for example device type can be acolecetd once a day, performances every 60" and state every 300"

    config_param :interval, :time #, :default => nil
    config_param :interval_perf, :time #, :default => nil
    config_param :tag, :string #, :default => "oms.heartbeat"
    config_param :nodes, :array, value_type: :string
    config_param :user_name, :string
    config_param :user_password, :string, secret: true
    config_param :retries, :integer, default: 3
    config_param :wait_seconds, :integer, default: 2  
    # Interval in seconds to refresh the cache
    config_param :ip_cache_refresh_interval, :integer, :default => 600

    def configure (conf)
      super
       @ip_cache = OMS::IPcache.new @ip_cache_refresh_interval
       $log.debug {"Configuring Kemp rest plugin"}       
    end

    def start     
      $log.debug {"Starting Kemp rest plugin with interval #{@interval} and perf interval #{@interval_perf}"}
      super
      if @interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      else
        get_status_data
      end
      if @interval_perf
        @finished = false
        @perf_condition = ConditionVariable.new
        @perf_mutex = Mutex.new
        @perf_thread = Thread.new(&method(:run_periodic_perf))
      else
        get_perf_data
      end
      
    end

    def shutdown
      if @interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
      if @interval_perf
        @perf_mutex.synchronize {
          @finished = true
          @perf_condition.signal
        }
        @perf_thread.join
      end      
      super
    end

    def get_status_data
      time = Time.now.to_f
      time = Engine.now

      #multi stream snippet follwowing, for consistency we will follow other OMS plugins
      #es = MultiEventStream.new
      #@nodes.each {|name|
      #  $log.debug {"Calling device_info for #{name} with time #{time}"}
      #   record=KempRest::KempDevice.device_info(name, @user_name, @user_password, @retries, @wait_seconds)
      #   es.add(time,record) unless record.nil?
      #}
      #tag= @tag + '.info'
      #$log.debug {"returning #{tag} data"}
      #router.emit_stream(tag, es) unless es.empty?
      #the format used by OMS is a little different they alway return one record that wraps many records
      #wrapper = {
      #   "DataType"=>"HEALTH_ASSESSMENT_BLOB",
      #   "IPName"=>"LogManagement",
      #   "DataItems"=>[data_item]
      #}
      # router.emit(@tag, time, wrapper) if wrapper


      #OMS consistent data, mettici un rescue
      records=[]
      @nodes.each {|name|
        $log.debug {"Calling device_info for #{name} with time #{time}"}
         record=KempRest::KempDevice.device_info(name, @user_name, @user_password, @retries, @wait_seconds)
         #unless record.empty?
            # use the tag to differentiate streams returned, in the end we will have a multistream payload with different wrappers
            record["Type"]='device_info'
            record["EventTime"] = OMS::Common.format_time(time)
            record["Computer"] = name
            record["HostIP"] = "Unknown IP"         
            host_ip = @ip_cache.get_ip(name)
            if host_ip.nil?
                OMS::Log.warn_once("Failed to get the IP for #{name}.")
            else
              record["HostIP"] = host_ip
            end         
            $log.debug {" well #{record}"}
            records << record
         #end
      }      
      if records.count == 0
        $log.warn {"No data returned for KempDevice.device_info"}
      end
      router.emit(@tag, time, records) unless records.count == 0
    end

    def get_perf_data
      time = Time.now.to_f
      time = Engine.now
      $log.trace {"get_perf_data"}
      #OMS consistent data
      records=[]
      $log.warn {"No data returned for get_perf_data"} if records.count == 0
      router.emit(@tag, time, records) unless records.count == 0
    end


    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @interval)
        done = @finished
        @mutex.unlock
        if !done
          get_status_data
        end
        @mutex.lock
      end
      @mutex.unlock
    end

    def run_periodic_perf
      @perf_mutex.lock
      done = @finished
      until done
        @perf_condition.wait(@perf_mutex, @interval_perf)
        done = @finished
        @perf_mutex.unlock
        if !done
          get_perf_data
        end
        @perf_mutex.lock
      end
      @perf_mutex.unlock
    end

  end # QNDKempRestInput

end # module

