module KempRest

require 'net/http'
require 'net/https'
require 'multi_xml'
require 'uri'
require 'logger'

require_relative 'oms_common'

#devices=[
#  {:names => ['smv-inf-kemp1a.asmn.net','smv-inf-kemp1b.asmn.net'], :user_name=>'bal', :user_password=>'TqEPaJr7ya'},
#  {:names => ['smx-inf-kemp1.asmn.net'], :user_name=>'bal', :user_password=>'TqEPaJr7ya'}
#]

#fluentd -p "C:\Ruby23-x64\Kemp\opt\microsoft\omsagent\plugin" -c "C:\Ruby23-x64\Kemp\etc\opt\microsoft\omsagent\conf\fluent.conf" -vv

#retries=2
#wait_secs=5
#infos=[]
#devices.each {  |device| 
#  device[:names].each {|name| infos << KempDevice.device_info(name, device[:user_name], device[:user_password], retries, wait_secs)}
#}
#
#p infos


class KempDevice
    
    @@log =  Logger.new(STDERR) #nil
    @@log.formatter = proc do |severity, time, progname, msg|
        "#{time} #{severity} #{msg}\n"
    end

  PROPS=['dfltgw', 'hamode', 'havhid', 'hastyle','backupenable','backuphost','ha1hostname','hostname','ha2hostname','serialnumber','version']

  def self.device_info (name, user_name, user_password, retries, wait_secs)
    #for ha1hostname better a regexp
    @@log.debug {"device_info: getting data for #{name}"}

    uri=URI("https://#{name}/access/getall")    
    req=Net::HTTP::Get.new(uri)
    req.basic_auth(user_name, user_password)
    http= Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl=true
    #more often than not Kemp devices use self signed certificates
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    device_info = nil
    begin
      response=http.request(req)
      device_info=MultiXml.parse(response.body) if response.code == '200'
    rescue => exception
      #log exception in some way
      retries-=1
      @@log.error { "device_info: Error reading data #{exception} remaining retries #{retries}" }
      sleep(wait_secs)
      retry if retries > 0
    else
      @@log.debug {"device_info: got data without any glitch #{name}"}
    end
    results={}
    unless device_info.nil?
      results = device_info['Response']['Success']['Data'].select {|tag, value| PROPS.include?(tag)}
    end
    results
  end
end

end