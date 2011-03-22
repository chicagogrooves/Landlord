class Apartment
  class << self
    alias :really_set_current= :current=
    # Does the actual ActiveRecord magic after the setting of the apartment
    def current= apt
      $stderr.puts "ApartmentHooks -> Apartment#current"
      self.really_set_current = apt
      
      tenants.each do |t|
        if apt.blank?
          Thread.current[:"#{t}_scoped_methods"] = []
        else
          conditions = apt.inject({}) do |part, (k,v)|
            part[k] = v; part
          end
          Thread.current[:"#{t}_scoped_methods"] = [{:find=>{:conditions=>conditions.dup}, :create=>conditions.dup}]
        end
      end
    end
  end
  
  module ControllerDetection
    def self.included(controller)
      controller.class_eval do
        prepend_before_filter :set_apartment

        def set_apartment
          logger.debug "ApplicationController#set_apartment"
          apt = Apartment.from_request(request) 
          Apartment.current = apt
        rescue Apartment::InvalidError => ex
          logger.warn "Could not create valid apartment. Error was: #{ex.message}. Request:#{[request.host, request.path, request.params]}"
          raise "Suspected request tampering. Landlord says: Could not create valid Apartment."
        end
      end
    end
  end
end

ApplicationController.class_eval do
  # Note code here is not automatically reloaded in dev mode - so for development mode to work
  # you actually need include Apartment::ControllerDetection in the controllers class def

  include Apartment::ControllerDetection
end
