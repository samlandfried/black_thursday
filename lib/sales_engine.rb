require_relative './merchant_repository'
require_relative './item_repository'
require_relative './invoice_repository'
require_relative './invoice_item_repository'

class SalesEngine

  attr_reader :merchants, :items, :invoices, :invoice_items
# Refactor: Create repositories with a "build params hash" method that extracts headers and vals from CSV row
  def initialize(paths)
    @merchants = MerchantRepository.from_csv(paths[:merchants], self)
    @items = ItemRepository.from_csv(paths[:items], self)
    @invoices = InvoiceRepository.from_csv(paths[:invoices], self)
    @invoice_items = InvoiceItemRepository.from_csv(paths[:invoice_items], self)
  end

  def self.from_csv(data_paths)
    new(data_paths)
  end

end
