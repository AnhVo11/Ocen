"""Unit tests for the bilingual work-event classifier."""

import pytest

from app.scheduler.classifier import is_work_related


class TestEnglishKeywords:
    def test_client_meeting(self):
        assert is_work_related("Meeting with client to review project") is True

    def test_contract_signing(self):
        assert is_work_related("Contract signing at head office") is True

    def test_deadline_reminder(self):
        assert is_work_related("Deadline for Q2 report submission") is True

    def test_budget_review(self):
        assert is_work_related("Budget review with finance team") is True

    def test_invoice_approval(self):
        assert is_work_related("Invoice approval for vendor payment") is True

    def test_proposal_presentation(self):
        assert is_work_related("Client proposal presentation") is True

    def test_board_meeting(self):
        assert is_work_related("Board meeting at headquarters") is True

    def test_audit(self):
        assert is_work_related("Annual audit review session") is True


class TestVietnameseKeywords:
    def test_hop_khach_hang(self):
        assert is_work_related("Họp với khách hàng về hợp đồng mới") is True

    def test_bao_cao(self):
        assert is_work_related("Nộp báo cáo tài chính quý II") is True

    def test_du_an(self):
        assert is_work_related("Cuộc họp dự án khu đô thị") is True

    def test_ban_giao(self):
        assert is_work_related("Bàn giao hồ sơ cho đối tác") is True

    def test_ngan_sach(self):
        assert is_work_related("Phê duyệt ngân sách năm tới") is True

    def test_cong_viec(self):
        assert is_work_related("Công việc cần hoàn thành trước deadline") is True


class TestMixedLanguage:
    def test_bilingual_event(self):
        assert is_work_related("Review báo cáo financial report Q3") is True

    def test_english_title_vn_notes(self):
        assert is_work_related("Strategy session — bàn về ngân sách 2027") is True


class TestNonWorkEvents:
    def test_birthday_dinner(self):
        assert is_work_related("Birthday dinner with family at restaurant") is False

    def test_personal_travel(self):
        assert is_work_related("Holiday trip to Phu Quoc beach resort") is False

    def test_gym(self):
        assert is_work_related("Morning gym session") is False

    def test_doctor(self):
        assert is_work_related("Doctor appointment at City International Hospital") is False

    def test_empty_string(self):
        assert is_work_related("") is False

    def test_whitespace_only(self):
        assert is_work_related("   ") is False

    def test_random_words(self):
        assert is_work_related("Lunch picnic with kids") is False


class TestEdgeCases:
    def test_case_insensitive_english(self):
        assert is_work_related("MEETING WITH CLIENT") is True

    def test_case_insensitive_mixed(self):
        assert is_work_related("Budget APPROVAL pending") is True

    def test_partial_word_no_match(self):
        # "clientele" should NOT match "client" (whole-word boundary)
        assert is_work_related("Clientele dinner with friends") is False
