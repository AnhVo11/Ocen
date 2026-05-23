"""Unit tests for travel feasibility utilities."""

import pytest

from app.scheduler.travel import VIETNAM_IATA, _get_iata, _parse_iso_duration, haversine


class TestHaversine:
    def test_same_point_is_zero(self):
        assert haversine(10.0, 106.0, 10.0, 106.0) == 0.0

    def test_hanoi_to_hcmc_approx(self):
        """Straight-line distance HAN→SGN is ~1,150 km."""
        lat_han, lng_han = 21.0285, 105.8542
        lat_sgn, lng_sgn = 10.8231, 106.6297
        dist = haversine(lat_han, lng_han, lat_sgn, lng_sgn)
        assert 1_100 <= dist <= 1_250, f"Expected ~1150 km, got {dist:.1f} km"

    def test_hanoi_to_da_nang_approx(self):
        """HAN→DAD is roughly 600 km by air."""
        lat_han, lng_han = 21.0285, 105.8542
        lat_dad, lng_dad = 16.0544, 108.2022
        dist = haversine(lat_han, lng_han, lat_dad, lng_dad)
        assert 550 <= dist <= 700

    def test_short_distance_under_100(self):
        """Two nearby points in HCMC should be well under 100 km."""
        dist = haversine(10.75, 106.65, 10.80, 106.70)
        assert dist < 20

    def test_symmetry(self):
        """haversine(A, B) == haversine(B, A)."""
        d1 = haversine(21.0, 105.8, 10.8, 106.6)
        d2 = haversine(10.8, 106.6, 21.0, 105.8)
        assert abs(d1 - d2) < 0.001


class TestParseIsoDuration:
    def test_hours_and_minutes(self):
        assert _parse_iso_duration("PT2H30M") == 150.0

    def test_hours_only(self):
        assert _parse_iso_duration("PT1H") == 60.0

    def test_minutes_only(self):
        assert _parse_iso_duration("PT45M") == 45.0

    def test_zero(self):
        assert _parse_iso_duration("PT0M") == 0.0

    def test_long_flight(self):
        assert _parse_iso_duration("PT3H15M") == 195.0


class TestVietnamIataMapping:
    def test_hanoi_aliases(self):
        assert VIETNAM_IATA["hanoi"] == "HAN"
        assert VIETNAM_IATA["hà nội"] == "HAN"
        assert VIETNAM_IATA["ha noi"] == "HAN"

    def test_hcmc_aliases(self):
        assert VIETNAM_IATA["ho chi minh"] == "SGN"
        assert VIETNAM_IATA["hcmc"] == "SGN"
        assert VIETNAM_IATA["saigon"] == "SGN"

    def test_da_nang(self):
        assert VIETNAM_IATA["da nang"] == "DAD"
        assert VIETNAM_IATA["đà nẵng"] == "DAD"

    def test_all_14_airports_present(self):
        expected_iata_codes = {
            "HAN", "SGN", "DAD", "DLI", "CXR",
            "HUI", "VII", "HPH", "BMV", "PQC",
            "VCA", "PXU", "UIH", "VDH",
        }
        assert expected_iata_codes.issubset(set(VIETNAM_IATA.values()))


class TestGetIata:
    def test_hanoi_substring(self):
        assert _get_iata("Sân bay Nội Bài, Hà Nội") == "HAN"

    def test_hcmc_substring(self):
        assert _get_iata("Quận 1, Ho Chi Minh") == "SGN"

    def test_none_for_unknown(self):
        assert _get_iata("Paris") is None

    def test_none_for_empty(self):
        assert _get_iata("") is None
