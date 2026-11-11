# Draft: UI only, no persistence yet.
class EventsController < ApplicationController
  def index
    now = Time.current.beginning_of_hour
    @events = [
      { id: 1, title: "กล้องฟิล์ม Nikon FM2",  type: "English", price: 4_500, start_at: now - 2.days, stop_at: now + 5.hours, status: "live" },
      { id: 4, title: "จักรยานไฮบริด มือสอง",   type: "English", price: 6_900, start_at: now + 1.day,  stop_at: now + 4.days, status: "upcoming" },
      { id: 6, title: "พระเครื่องเก่า",          type: "English", price: 25_000, start_at: now - 5.days, stop_at: now - 1.day,  status: "ended" }
    ]
  end

  def new
    @products = [ "กล้องฟิล์ม Nikon FM2", "นาฬิกา Seiko 5 วินเทจ", "กีตาร์โปร่ง Yamaha F310" ]
  end
end
