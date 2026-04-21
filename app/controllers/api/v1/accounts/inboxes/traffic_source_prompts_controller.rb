class Api::V1::Accounts::Inboxes::TrafficSourcePromptsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def index
    prompts = @inbox.traffic_source_prompts.order(updated_at: :desc)
    render json: {
      payload: prompts.map { |prompt| serialize_prompt(prompt) }
    }
  end

  def current
    prompt = find_prompt
    return render_not_found if prompt.blank?

    render json: { payload: serialize_prompt(prompt).merge(prompt_text: prompt.prompt_text) }
  end

  def create
    return render json: { error: 'file is required' }, status: :unprocessable_entity if params[:file].blank?

    extracted_text = TrafficSourcePromptExtractor.new(params[:file]).extract!
    prompt = find_prompt_for_upsert || @inbox.traffic_source_prompts.new(source_id: source_id)
    prompt.account_id = Current.account.id
    prompt.file_name = params[:file].original_filename.to_s
    prompt.prompt_text = extracted_text
    prompt.save!

    render json: { payload: serialize_prompt(prompt).merge(prompt_text: prompt.prompt_text) }, status: :ok
  rescue TrafficSourcePromptExtractor::UnsupportedFormatError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue TrafficSourcePromptExtractor::EmptyFileError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue TrafficSourcePromptExtractor::ExtractionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def download
    prompt = find_prompt
    return render_not_found if prompt.blank?

    send_data(
      prompt.prompt_text,
      filename: "#{prompt.file_name.to_s.sub(/\.[^.]+\z/, '')}.txt",
      type: 'text/plain; charset=utf-8',
      disposition: 'attachment'
    )
  end

  def destroy
    prompt = find_prompt
    return render_not_found if prompt.blank?

    prompt.destroy!
    head :no_content
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def source_id
    params[:source_id].to_s.strip.presence
  end

  def find_prompt
    TrafficSourcePrompt.prompt_for(
      account_id: Current.account.id,
      inbox_id: @inbox.id,
      source_id: source_id
    )
  end

  def find_prompt_for_upsert
    if source_id.present?
      @inbox.traffic_source_prompts.find_by(source_id: source_id)
    else
      @inbox.traffic_source_prompts.find_by(source_id: [nil, ''])
    end
  end

  def render_not_found
    render json: { error: 'Prompt not found for source' }, status: :not_found
  end

  def serialize_prompt(prompt)
    {
      source_id: prompt.source_id,
      file_name: prompt.file_name,
      updated_at: prompt.updated_at
    }
  end
end
