from pathlib import Path
import unittest

from test_ios_completion_busy import member

ROOT = Path(__file__).resolve().parents[2]


class OverlappingCreateSortOrderTests(unittest.TestCase):
    def test_create_reserves_sort_order_before_session_and_transport(self):
        source = (ROOT / "ios/Shared/ReminderStore.swift").read_text()
        create = member(source, "func createAcknowledged(")
        self.assertIn("+ pendingCreates", create)
        self.assertLess(create.index("let nextOrder"), create.index("loadFreshSession"))
        self.assertLess(create.index("let nextOrder"), create.index("requestData"))
        tests = (ROOT / "ios/Tests/ReminderStoreReorderTests.swift").read_text()
        proof = member(tests, "func testOverlappingCreatesReserveDistinctSortOrders(")
        self.assertIn("postedSortOrders", proof)
        self.assertIn("[7, 8]", proof)


if __name__ == "__main__":
    unittest.main()
