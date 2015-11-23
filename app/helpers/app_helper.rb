# Helper methods defined here can be accessed in any controller or view in the application

module RestfulApi
  class App
    module AppHelper
      HTTP_METHODS_REQUIRES_BODY = %w(POST PATCH PUT)

      def body_valid?(body, valid_keys)
        body.keys.each do |key|
          return false unless valid_keys.include? key
        end

        true
      end

      def request_requires_body?(request)
        HTTP_METHODS_REQUIRES_BODY.include? request.env['REQUEST_METHOD']
      end

      def sinatra_error_key_name
        'sinatra.error'
      end

      # padrino's adds raised errors inside env['sinatra.error'] by default and returns a ugly response
      # this method can be used to catch them and prevent the default behaviour
      def sinatra_error_is_a?(env, klass)
        !env[sinatra_error_key_name].blank? && env[sinatra_error_key_name].is_a?(klass)
      end

    end

    helpers AppHelper
  end
end