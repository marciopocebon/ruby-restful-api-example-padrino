module RestfulApi
  class App < Padrino::Application
    use ConnectionPoolManagement
    register Padrino::Helpers

    # enable :sessions

    ##
    # Caching support.
    #
    # register Padrino::Cache
    # enable :caching
    #
    # You can customize caching store engines:
    #
    # set :cache, Padrino::Cache.new(:LRUHash) # Keeps cached values in memory
    # set :cache, Padrino::Cache.new(:Memcached) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Memcached, :server => '127.0.0.1:11211', :exception_retry_limit => 1)
    # set :cache, Padrino::Cache.new(:Memcached, :backend => memcached_or_dalli_instance)
    # set :cache, Padrino::Cache.new(:Redis) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Redis, :host => '127.0.0.1', :port => 6379, :db => 0)
    # set :cache, Padrino::Cache.new(:Redis, :backend => redis_instance)
    # set :cache, Padrino::Cache.new(:Mongo) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Mongo, :backend => mongo_client_instance)
    # set :cache, Padrino::Cache.new(:File, :dir => Padrino.root('tmp', app_name.to_s, 'cache')) # default choice
    #

    ##
    # Application configuration options.
    #
    # set :raise_errors, true       # Raise exceptions (will stop application) (default for test)
    # set :dump_errors, true        # Exception backtraces are written to STDERR (default for production/development)
    # set :show_exceptions, true    # Shows a stack trace in browser (default for development)
    # set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
    # set :public_folder, 'foo/bar' # Location for static assets (default root/public)
    # set :default_builder, 'foo'   # Set a custom form builder (default 'StandardFormBuilder')
    # set :locale_path, 'bar'       # Set path for I18n translations (default your_apps_root_path/locale)
    # layout  :my_layout            # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
    set :reload, false            # Reload application files (default in development)
    # disable :sessions             # Disabled sessions by default (enable if needed)
    disable :flash                # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
    disable :protect_from_csrf
    disable :layout

    ##
    # You can configure for a specified environment like:
    #
    #   configure :development do
    #     set :foo, :bar
    #     disable :asset_stamp # no asset timestamping for dev
    #   end
    #

    ##
    # You can manage errors like:
    #
    #   error 404 do
    #     render 'errors/404'
    #   end
    #
    #   error 500 do
    #     render 'errors/500'
    #   end
    #

    # TODO: test me!
    before do
      # parses the body, if needed
      body = request.body.read
      @request_requires_body = request_requires_body?(request)
      @request_body = JSON.parse body if @request_requires_body && !body.blank?

      # halts if body is required and absent
      halt 400, {'Content-Type' => 'application/json'}, nil if @request_requires_body && @request_body.blank?
    end

    after do
      # halts if some of the keys from request's body is not valid
      halt 400, {'Content-Type' => 'application/json'}, nil if sinatra_error_is_a? ActiveRecord::UnknownAttributeError
    end

    private
    def sinatra_error_key_name
      @sinatra_error_key_name ||= sinatra_error = 'sinatra.error'
    end

    # padrino's adds raised errors inside @env['sinatra.error'] by default and returns a ugly response
    # this method can be used to catch them and prevent the default behaviour
    def sinatra_error_is_a?(klass)
      !@env[sinatra_error_key_name].blank? && @env[sinatra_error_key_name].is_a?(klass)
    end
  end
end
