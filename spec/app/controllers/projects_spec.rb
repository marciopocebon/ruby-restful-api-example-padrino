require_relative '../../support/shared_examples/successful_response'

describe '/projects' do
  let(:url) { '/projects' }

  describe 'GET /' do
    let(:projects) { build_list :project, 2 }
    let(:params) { { page: Faker::Number.digit, per_page: Faker::Number.digit, format: nil } }
    let(:fetched_projects) { Kaminari.paginate_array(projects).page(params[:page]) }

    before do
      allow(Project).to receive(:page).and_return(fetched_projects)
      allow(fetched_projects).to receive(:per).and_call_original
      allow(Paginator).to receive(:paginate_relation).and_call_original
    end

    after do
      get url, params
    end

    it 'fetches all projects from :page' do
      expect(Project).to receive(:page).with(params[:page])
    end

    it 'limits the number of projects per page with param[:per_page]' do
      expect(fetched_projects).to receive(:per).with(params[:per_page])
    end

    it 'paginates the response body' do
      expect(Paginator).to receive(:paginate_relation).with(fetched_projects, params).at_most(1).times
    end

    context 'when no project is found' do
      let(:projects) { [] }
      let(:fetched_projects) { Kaminari.paginate_array(projects).page(params[:page]) }
      let(:expected_response_body) { Paginator.paginate_relation(fetched_projects, params).to_json }

      before do
        get url, params
      end

      it 'returns an empty response' do
        expect(last_response.body).to eq expected_response_body
      end

      include_examples :successful_ok_response
    end

    context 'when there are projects found' do
      let(:projects) { build_list :project, 1 }
      let(:fetched_projects) { Kaminari.paginate_array(projects).page(params[:page]) }
      let(:expected_response_body) { Paginator.paginate_relation(fetched_projects, params).to_json }

      before do
        get url, params
      end

      it 'returns the projects in the response body' do
        expect(last_response.body).to eq expected_response_body
      end

      include_examples :successful_ok_response
    end

  end

  describe 'DELETE /' do
    before do
      delete url
    end

    after do
      delete url
    end

    it 'deletes all projects' do
      expect(Project).to receive(:delete_all)
    end

    include_examples :successful_no_content_response

  end

  describe 'POST /' do

    context 'when request body is empty' do
      before do
        post url
      end

      include_examples :unsuccessful_bad_request_response
    end

    context 'when request body is not empty' do
      let(:project) { build :project }
      let(:request_body) { JSON.parse(project.to_json) }

      before do
        allow(Project).to receive(:new).and_return(project)
      end

      after do
        post url, project.to_json
      end

      it 'builds a new project' do
        expect(Project).to receive(:new).with(request_body)
      end

      it 'saves the project' do
        expect(project).to receive(:save)
      end

      context 'when the project is valid' do

        before do
          post url, project.to_json
        end

        include_examples :successful_created_response
      end

      context 'when the project is invalid' do
        let(:project) { build :project, :invalid }

        before do
          post url, project.to_json
        end

        include_examples :unsuccessful_unprocessable_entity_response
      end
    end
  end

  describe 'GET /:id' do
    let(:project) { build :project }
    let(:id) { Faker::Number.digit }
    let(:uri) { url.dup.concat "/#{id}" }
    let(:cache_key) { "#{RestfulApi::App::ProjectsHelper::CACHE::DEFAULT_KEY_PREFIX}#{id}" }
    let(:cache_expiration) { RestfulApi::App::ProjectsHelper::CACHE::DEFAULT_EXPIRATION }

    it 'fetches the project from redis' do
      expect(RedisProvider).to receive(:get).with(cache_key)

      get uri
    end

    context 'when it is found in redis' do
      before do
        allow(RedisProvider).to receive(:get).with(cache_key).and_return(project.to_json)

        get uri
      end

      after do
        get uri
      end

      it 'returns it' do
        expect(last_response.body).to eq project.to_json
      end

      it 'does not fetch it from database' do
        expect(Project).not_to receive(:find_by_id).with(id)
      end

      include_examples :successful_ok_response
    end

    context 'when it is not found in redis' do

      before do
        allow(RedisProvider).to receive(:get).with(cache_key).and_return(nil)
      end

      it 'fetches the project with the provided :id' do
        expect(Project).to receive(:find_by_id).with(id)

        get uri
      end

      context 'when it exists' do

        before do
          allow(Project).to receive(:find_by_id).with(id).and_return(project)

          get uri
        end

        after do
          get uri
        end

        it 'caches it in redis' do
          expect(RedisProvider).to receive(:set).with(cache_key, project.to_json, cache_expiration)
        end

        it 'returns it' do
          expect(last_response.body).to eq project.to_json
        end

        include_examples :successful_ok_response
      end

      context 'when it does not exist' do
        before do
          allow(Project).to receive(:find_by_id).with(id).and_return(nil)

          get uri
        end

        it 'returns an empty body' do
          expect(last_response.body).to be_blank
        end

        it 'does not cache it in redis' do
          expect(RedisProvider).not_to receive(:set).with(cache_key, project.to_json, cache_expiration)
        end

        include_examples :unsuccessful_not_found_response
      end
    end
  end

  describe 'PATCH /:id' do
    let(:project) { build :project }
    let(:id) { Faker::Number.digit }
    let(:uri) { url.dup.concat "/#{id}" }
    let(:cache_key) { "#{RestfulApi::App::ProjectsHelper::CACHE::DEFAULT_KEY_PREFIX}#{id}" }
    let(:request_body) { JSON.parse project.to_json }

    context 'when request body is empty' do
      before do
        patch uri
      end

      include_examples :unsuccessful_bad_request_response
    end

    context 'when request body is not empty' do

      before do
        allow(Project).to receive(:update).with(id, request_body).and_return(project)
      end

      it 'updates the project\'s attributes' do
        expect(Project).to receive(:update).with(id, request_body)

        patch uri, project.to_json
      end

      context 'when the project exists' do
        before do
          allow(Project).to receive(:update).with(id, project.as_json).and_return(project)

          patch uri, project.to_json
        end

        after do
          patch uri, project.to_json
        end

        context 'when it is valid' do

          it 'removes it from redis' do
            expect(RedisProvider).to receive(:del).with(cache_key)
          end

          include_examples :successful_no_content_response
        end

        context 'when it is not valid' do
          let(:project) { build :project, :invalid }

          it 'does not try to remove it from redis' do
            expect(RedisProvider).not_to receive(:del).with(cache_key)
          end

          include_examples :unsuccessful_unprocessable_entity_response
        end
      end

      context 'when the project does not exist' do
        before do
          allow(Project).to receive(:update).with(id, request_body).and_raise(ActiveRecord::RecordNotFound)

          patch uri, project.to_json
        end

        after do
          patch uri, project.to_json
        end

        it 'does not try to remove it from redis' do
          expect(RedisProvider).not_to receive(:del).with(cache_key)
        end

        include_examples :unsuccessful_not_found_response
      end
    end
  end

  describe 'DELETE /:id' do
    let(:id) { Faker::Number.digit }
    let(:uri) { url.dup.concat "/#{id}" }
    let(:cache_key) { "#{RestfulApi::App::ProjectsHelper::CACHE::DEFAULT_KEY_PREFIX}#{id}" }

    it 'tries to delete the project with the provided :id' do
      expect(Project).to receive(:delete).with(id)

      delete uri
    end

    context 'when it was delete' do
      before do
        allow(Project).to receive(:delete).with(id).and_return(1)

        delete uri
      end

      after do
        delete uri
      end

      it 'removes it from redis' do
        expect(RedisProvider).to receive(:del).with(cache_key)
      end

      include_examples :successful_no_content_response
    end

    context 'when it was not deleted' do
      before do
        allow(Project).to receive(:delete).with(id).and_return(0)

        delete uri
      end

      after do
        delete uri
      end

      it 'does not try to remove it from redis' do
        expect(RedisProvider).not_to receive(:del).with(cache_key)
      end

      include_examples :unsuccessful_not_found_response
    end
  end
end
