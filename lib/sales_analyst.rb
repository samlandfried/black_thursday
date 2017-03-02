class SalesAnalyst
  attr_reader :se,
    :avg_items_per_merchant,
    :avg_items_per_merchant_std_dev

  def initialize(sales_engine)
    @se = sales_engine
    @avg_items_per_merchant = average_items_per_merchant
    @avg_items_per_merchant_std_dev =
      average_items_per_merchant_standard_deviation
  end

  def average_items_per_merchant
    (se.items.all.count.to_f / se.merchants.all.count.to_f).round(2)
  end

  def average_items_per_merchant_standard_deviation
    items_per_merchant = se.merchants.all.map do |merchant|
      merchant.items.count
    end
    find_standard_deviation(items_per_merchant)
  end

  def find_standard_deviation(set)
    average = find_average(set)
    squared_diffs = set.reduce(0) do |memo, entry|
      memo += ((entry - average) ** 2)
    end
    std_dev = Math.sqrt(squared_diffs.to_f / (set.count - 1)).round(2)
  end

  def merchants_with_high_item_count
    se.merchants.all.select do |merchant|
      threshold = avg_items_per_merchant + avg_items_per_merchant_std_dev
      merchant.items.count > threshold
    end
  end

  def average_item_price_for_merchant(merchant_id)
    merchant = se.merchants.find_by_id(merchant_id)
    total = merchant.items.reduce(0) do |sum, item|
      sum += item.unit_price
    end
    (total / merchant.items.count).round(2)
  end

  def average_average_price_per_merchant
    total = se.merchants.all.reduce(0) do |sum, merchant|
      sum += average_item_price_for_merchant(merchant.id)
    end
    (total / se.merchants.all.count).round(2)
  end

  def golden_items
    all_items_unit_price = se.items.all.map do |item|
      item.unit_price
    end
    std_dev = find_standard_deviation(all_items_unit_price)

    se.items.all.select do |item|
      item.unit_price > (std_dev * 2) + find_average(all_items_unit_price)
    end
  end

  def average_invoices_per_merchant
    s = se.merchants.all.map do |merchant|
      merchant.invoices.count
    end
    find_average(s)
  end

  def average_invoices_per_merchant_standard_deviation
    invoices_per_merchant = se.merchants.all.reduce([]) do |memo, merchant|
      memo << merchant.invoices.count
    end
    find_standard_deviation(invoices_per_merchant)
  end

  def find_average(set)
    (set.reduce(:+) / set.count.to_f).round(2)
  end

  def top_merchants_by_invoice_count
    set = se.merchants.all.map do |merchant|
      merchant.invoices.count
    end
    whale_threshold = find_average(set) + (find_standard_deviation(set) * 2)
    se.merchants.all.select do |merchant|
      merchant.invoices.count > whale_threshold
    end
  end

  def bottom_merchants_by_invoice_count
    set = se.merchants.all.map do |merchant|
      merchant.invoices.count
    end
    guppy_threshold = find_average(set) - (find_standard_deviation(set) * 2)
    se.merchants.all.select do |merchant|
      merchant.invoices.count < guppy_threshold
    end
  end

  def find_day(entry)
    entry.created_at.strftime('%A')
  end

  def find_entries_for_each_day(set)
    set.reduce(Hash.new(0)) do | day_hash, entry|
      day = find_day(entry)
      day_hash[day] += 1
      day_hash
    end
  end

  def calculate_total_daily_entries(set)
    set.reduce([]) do |memo, (day, count)|
      memo << count
      memo
    end

  end

  def top_days_by_invoice_count
    entries = find_entries_for_each_day(se.invoices.all)
    day_counts = calculate_total_daily_entries(entries)
    average = find_average(day_counts)
    std_dev = find_standard_deviation(day_counts)
    days_threshold = average + std_dev
    entries = find_entries_for_each_day(se.invoices.all)
    entries.reduce([]) do |top_days, (day, count)|
      top_days << day if count > days_threshold
      top_days
    end
  end

  def invoice_status(status)
    statuses = se.invoices.all.reduce(Hash.new(0)) do | status_hash, entry|
      status_hash[entry.status] += 1
      status_hash
    end
    ((statuses[status] / se.invoices.all.count.to_f) * 100).round(2)
  end

  def top_merchant_for_customer(customer_id)
    customer = se.customers.find_by_id(customer_id)
    invoices = se.invoices.all.select do |invoice|
      invoice.customer_id == customer_id
    end
    invoice_items = invoices.collect do |invoice|
      se.invoice_items.find_all_by_invoice_id(invoice.id)
    end.flatten
    grouped = invoice_items.group_by do |ii|
      se.invoices.find_by_id(ii.invoice_id).merchant_id
    end
    purchases_count =
    grouped.reduce(Hash.new(0)) do |hash, (merchant_id, invoice_items)|
      hash[merchant_id] = invoice_items.reduce(0) do |total, invoice_item|
        total += invoice_item.quantity
      end
      hash
    end
    merchant_id = purchases_count.max_by do |merchant_id, purchases_count|
      purchases_count
    end.first
    se.merchants.find_by_id(merchant_id)
  end

  def one_time_buyers
    se.customers.all.select do |customer|
      customer.fully_paid_invoices.count == 1
    end
  end

  def one_time_buyers_invoices
    one_time_buyers.map(&:invoices).flatten
  end

  def get_invoice_items_from(invoices)
    invoices.map(&:invoice_items).flatten
  end

  def one_time_buyers_items
    paid_invoices = one_time_buyers_invoices.select(&:is_paid_in_full?)
    invoice_items = get_invoice_items_from(paid_invoices)
    retrieve_top_selling_items(invoice_items)
  end

  def purchases_count(invoice_items)
    invoice_items.reduce(Hash.new(0)) do |hash, invoice_item|
      hash[invoice_item.item_id] += invoice_item.quantity
      hash
    end
  end

  def retrieve_top_selling_items(item_id_and_count)
    items_purchase_frequency = purchases_count(item_id_and_count)
    max_sales = items_purchase_frequency.max_by { |x| x.last }.last
    get_items_sold_x_times(items_purchase_frequency, max_sales)
  end

  def get_items_sold_x_times(item_ids, x)
    item_ids.reduce([]) do |items, item_id_and_count|
      item = se.items.find_by_id(item_id_and_count.first)
      items << item if item_id_and_count.last == x
      items
    end
  end

  def highest_volume_items(customer_id)
    invoices = se.invoices.find_all_by_customer_id(customer_id)
    invoice_items = invoices.map do |invoice|
      se.invoice_items.find_all_by_invoice_id(invoice.id)
    end.flatten

    quantity = invoice_items.max_by do |invoice_item|
      invoice_item.quantity
    end.quantity

    invoice_items_with_highest_quantity = invoice_items.select do |invoice_item|
      invoice_item.quantity == quantity
    end

    items = invoice_items_with_highest_quantity.map do |invoice_item|
      item = se.items.find_by_id(invoice_item.item_id)
      Item.new('./test/fixtures/items_truncated.csv', nil) unless item
    end
  end

  def top_buyers(n = 20)
    se.customers.all.sort_by do |customer|
      invoices = se.invoices.find_all_by_customer_id(customer.id)
      invoices.reduce(0) do  |total, invoice|
        total += invoice.total if invoice.is_paid_in_full?
        total
      end
    end.last(n).reverse
  end

  def best_invoice_by_quantity
    invoices = se.invoices.all.select do |invoice|
      invoice.is_paid_in_full?
    end
    invoices.max_by do |invoice|
      invoice.invoice_items.reduce(0) do |total, invoice_item|
        total += invoice_item.quantity
      end
    end
  end

  def best_invoice_by_revenue
    invoices = se.invoices.all.select do |invoice|
      invoice.is_paid_in_full?
    end
    invoices.max_by do |invoice|
      invoice.total
    end
  end

  def customers_with_unpaid_invoices
    se.customers.all.select do |customer|
      invoices = se.invoices.find_all_by_customer_id(customer.id)
      !invoices.all? do |invoice|
        invoice.is_paid_in_full?
      end
    end
  end

  def items_bought_in_year(customer_id, year)
    customer_invoices = se.invoices.find_all_by_customer_id(customer_id)
    invoices = []
    customer_invoices.map do |invoice|
      year_match = invoice.created_at.year == year && invoice.is_paid_in_full?
      invoices << invoice.id if year_match
    end
    invoices.map do |invoice_id|
      se.invoices.find_by_id(invoice_id).items
    end.flatten
  end
end
