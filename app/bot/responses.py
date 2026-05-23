"""Pre-built WhatsApp response message templates.

All user-facing strings live here so they can be updated without touching
business logic.  Messages are bilingual (Vietnamese primary, English cues)
to suit the executive's team in Vietnam.
"""

# ---------------------------------------------------------------------------
# Welcome & navigation
# ---------------------------------------------------------------------------

WELCOME_MESSAGE = (
    "Xin chào! Gõ *thêm* để thêm lịch mới hoặc *danh sách* để xem lịch.\n"
    "_(Hi! Type *new* to add a schedule or *list* to view upcoming events.)_"
)

HELP_MESSAGE = (
    "📋 *Hướng dẫn sử dụng OCEN Bot*\n\n"
    "• *thêm* / *new* — Thêm sự kiện mới\n"
    "• *danh sách* / *list* — Xem lịch sắp tới\n"
    "• *hủy* / *cancel* — Hủy thao tác hiện tại\n"
    "• *giúp đỡ* / *help* — Xem hướng dẫn này\n\n"
    "Trong lúc nhập lịch, gửi *hủy* bất cứ lúc nào để thoát."
)

EXECUTIVE_ONLY_MESSAGE = (
    "ℹ️ Số của bạn được đăng ký là *Giám đốc*. "
    "Bạn sẽ nhận thông báo tự động về lịch trình.\n"
    "_(Your number is registered as Executive — you will receive automatic schedule reminders.)_"
)

UNKNOWN_USER_MESSAGE = (
    "⛔ Số điện thoại của bạn chưa được đăng ký trong hệ thống.\n"
    "Vui lòng liên hệ quản trị viên để được cấp quyền truy cập.\n"
    "_(Your number is not registered. Please contact the administrator.)_"
)

ERROR_MESSAGE = (
    "❌ Đã xảy ra lỗi. Vui lòng thử lại hoặc gõ *hủy* để thoát.\n"
    "_(An unexpected error occurred. Please try again or type *cancel*.)_"
)

# ---------------------------------------------------------------------------
# Schedule creation flow
# ---------------------------------------------------------------------------

ASK_TITLE = (
    "📝 *Tên sự kiện là gì?*\n"
    "_(What is the event title?)_"
)

ASK_DATE = (
    "📅 *Ngày diễn ra?*\n"
    "Định dạng: DD/MM/YYYY (ví dụ: 25/05/2026)\n"
    "_(Date? Format: DD/MM/YYYY — e.g. 25/05/2026)_"
)

ASK_TIME = (
    "🕐 *Giờ bắt đầu và kết thúc?*\n"
    "Định dạng: HH:MM - HH:MM (ví dụ: 09:00 - 17:00 hoặc 9h00 - 17h00)\n"
    "_(Start and end time? Format: HH:MM - HH:MM)_"
)

ASK_LOCATION = (
    "📍 *Địa điểm tổ chức?*\n"
    "Nhập tên địa điểm hoặc địa chỉ đầy đủ.\n"
    "_(Location? Enter the venue name or full address.)_"
)

ASK_NOTES = (
    "📒 *Ghi chú thêm?* (nếu không có, gõ *-* hoặc *bỏ qua*)\n"
    "_(Any additional notes? If none, type *-* or *skip*.)_"
)

# Placeholders: {title}, {date}, {start}, {end}, {location}, {notes}
CONFIRM_TEMPLATE = (
    "✅ *Xác nhận thông tin lịch:*\n\n"
    "📌 *Tên:* {title}\n"
    "📅 *Ngày:* {date}\n"
    "🕐 *Giờ:* {start} – {end}\n"
    "📍 *Địa điểm:* {location}\n"
    "📒 *Ghi chú:* {notes}\n\n"
    "Gõ *Có* để lưu hoặc *Không* để hủy.\n"
    "_(Type *Yes* to save or *No* to cancel.)_"
)

# Placeholder: {title}
SAVED_MESSAGE = (
    "✅ Đã lưu lịch *{title}* thành công!\n"
    "Giám đốc sẽ nhận thông báo nhắc nhở trước sự kiện."
)

CANCELLED_MESSAGE = (
    "🚫 Đã hủy thao tác. Gõ *thêm* để bắt đầu lại.\n"
    "_(Operation cancelled. Type *new* to start over.)_"
)

# ---------------------------------------------------------------------------
# Conflict & travel warnings
# ---------------------------------------------------------------------------

# Placeholder: {titles}
CONFLICT_WARNING = (
    "⚠️ *Cảnh báo xung đột lịch!*\n"
    "Sự kiện này trùng với: {titles}\n"
    "Lịch vẫn đã được lưu — vui lòng kiểm tra lại với Giám đốc."
)

# Placeholder: {message}
TRAVEL_WARNING = (
    "🚨 *Cảnh báo di chuyển!*\n"
    "{message}"
)

# ---------------------------------------------------------------------------
# List view
# ---------------------------------------------------------------------------

LIST_HEADER = "📆 *Lịch sắp tới:*\n"

NO_EVENTS_MESSAGE = (
    "📭 Hiện không có sự kiện nào trong lịch.\n"
    "_(No upcoming events found.)_"
)
