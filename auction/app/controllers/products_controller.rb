# Draft: UI only, no persistence yet.
class ProductsController < ApplicationController
  def index
    @products = [
      { code: "P-0001", name: "กล้องฟิล์ม Nikon FM2", category: "กล้อง",  status: "in_event" },
      { code: "P-0002", name: "นาฬิกา Seiko 5 วินเทจ", category: "นาฬิกา", status: "available" },
      { code: "P-0003", name: "กีตาร์โปร่ง Yamaha F310", category: "เครื่องดนตรี", status: "sold" }
    ]
    @status_labels = { "available" => "พร้อมประมูล", "in_event" => "อยู่ในอีเวนต์", "sold" => "ขายแล้ว" }
  end

  def new
  end
end
