class ConversationFinder
  attr_reader :current_user, :current_account, :params

  ASSIGNEE_TYPES = { me: 0, unassigned: 1, all: 2 }.freeze

  ASSIGNEE_TYPES_BY_ID = ASSIGNEE_TYPES.invert
  ASSIGNEE_TYPES_BY_ID.default = :me

  # assumptions
  # inbox_id if not given, take from all conversations, else specific to inbox
  # assignee_type if not given, take 'me'
  # conversation_status if not given, take 'open'

  # response of this class will be of type
  # {conversations: [array of conversations], count: {open: count, resolved: count}}

  # params
  # assignee_type_id, inbox_id, :conversation_status_id,

  def initialize(current_user, params)
    @current_user = current_user
    @current_account = current_user.account
    @params = params
  end

  def perform
    set_inboxes
    set_assignee_type

    find_all_conversations
    filter_by_status

    mine_count, unassigned_count, all_count = find_conversation_count

    filter_by_assignee_type

    {
      conversations: @conversations.latest,
      count: {
        mine_count: mine_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  private

  def set_inboxes
    if params[:inbox_id]
      @inbox_ids = current_account.inboxes.where(id: params[:inbox_id])
    else
      if @current_user.administrator?
        @inbox_ids = current_account.inboxes.pluck(:id)
      elsif @current_user.agent?
        @inbox_ids = @current_user.assigned_inboxes.pluck(:id)
      end
    end
  end

  def set_assignee_type
    @assignee_type_id = ASSIGNEE_TYPES[ASSIGNEE_TYPES_BY_ID[params[:assignee_type_id].to_i]]
  end

  def find_all_conversations
    @conversations = current_account.conversations.where(inbox_id: @inbox_ids)
  end

  def filter_by_status
    if params[:conversation_status_id].to_i.zero?
      @conversations = @conversations.open
    else
      @conversations = @conversations.resolved
    end
  end

  def filter_by_assignee_type
    if @assignee_type_id == ASSIGNEE_TYPES[:me]
      @conversations = @conversations.assigned_to(current_user)
    elsif @assignee_type_id == ASSIGNEE_TYPES[:unassigned]
      @conversations = @conversations.unassigned
    elsif @assignee_type_id == ASSIGNEE_TYPES[:all]
      @conversations
    end
    @conversations
  end

  def find_conversation_count
    [
      @conversations.assigned_to(current_user).count,
      @conversations.unassigned.count,
      @conversations.count
    ]
  end
end
