class Customer

  extend ClassMethods

  attr_reader :id,
    :first_name,
    :last_name,
    :created_at,
    :updated_at,
    :se

  def initialize(params, sales_engine)
    params = Customer.read_csv(params).first if params.instance_of?(String)
    @se = sales_engine
    @id = params[:id].to_i
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @created_at = Time.parse(params[:created_at])
    @updated_at = Time.parse(params[:updated_at])
  end

  def merchants
    common_invoices = se.invoices.find_all_by_customer_id(id)
    merchant_ids = common_invoices.reduce([]) do |uniq_merchants_ids, invoice|
      id_present = uniq_merchants_ids.include?(invoice.merchant_id)
      uniq_merchants_ids << invoice.merchant_id unless id_present
      uniq_merchants_ids
    end
    merchant_ids.map do |merchant_id|
      se.merchants.find_by_id(merchant_id)
    end
  end

  def invoices
    se.invoices.find_all_by_customer_id(id)
  end

  def fully_paid_invoices
    invoices = se.invoices.find_all_by_customer_id(id)
    invoices.select do |invoice|
      invoice.is_paid_in_full?
    end
  end
end
