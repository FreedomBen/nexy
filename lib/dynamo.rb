require 'aws-sdk'

class DynamoDB
  def initialize(botname:)
    @botname = botname
    @client = Aws::DynamoDB::Client.new(
      region: $slackbotfrd_conf['dynamo_region'],
      credentials: Aws::Credentials.new(
        access_key_id,
        secret_access_key
      )
    )
  end

  def put_item(table:, primary:, attrs: {})
    @client.put_item(
      table_name: ns_table_name(table),
      item: {
        'id' => primary
      }.merge(attrs),
      return_values: 'NONE'
    )
  end

  def get_item(table:, primary:)
    @client.get_item(
      table_name: ns_table_name(table),
      key: {
        'id' => primary
      },
      consistent_read: true,
      # attributes_to_get: %w[one two],
      return_consumed_capacity: 'INDEXES'
    )
  end

  def create_table(table_name, if_not_exist: true)
    return if if_not_exist && table_exists?(ns_table_name(table_name))

    @client.create_table(
      attribute_definitions: [
        {
          attribute_name: 'id',
          attribute_type: 'S'
        }
      ],
      table_name: ns_table_name(table_name),
      key_schema: [
        {
          attribute_name: 'id', # this attribute_name must match the one in attribute_definitions
          key_type: 'HASH' # HASH or RANGE
        }
      ],
      provisioned_throughput: {
        read_capacity_units: 1,
        write_capacity_units: 1
      }
    )
  end

  def list_tables
    @client.list_tables
  end

  alias tables list_tables

  def table_exists?(table_name)
    # We will cache the table names because this is
    # a check that we make often
    @table_names ||= []
    return true if @table_names.include?(ns_table_name(table_name))
    @table_names = list_tables.table_names
    @table_names.include?(ns_table_name(table_name))
  end

  private

  def ns_table_name(table_name)
    return table_name if table_name.starts_with?(@botname)
    "#{@botname}_#{table_name}"
  end

  def access_key_id
    retrieve_credential('DYNAMO_ACCESS_KEY_ID', 'AWS_ACCESS_KEY_ID')
  end

  def secret_access_key
    retrieve_credential('DYNAMO_SECRET_ACCESS_KEY', 'AWS_SECRET_ACCESS_KEY')
  end

  def retrieve_credential(specific, generic)
    retval = $slackbotfrd_conf[specific]
    retval = $slackbotfrd_conf[specific.downcase] if retval.nil? || retval.empty?
    retval = $slackbotfrd_conf[generic] if retval.nil? || retval.empty?
    return retval.chomp if retval
    ''
  end
end
