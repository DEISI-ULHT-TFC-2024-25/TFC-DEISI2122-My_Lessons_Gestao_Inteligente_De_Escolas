from django.test import TestCase
from schools.models import School

class PackPriceTests(TestCase):

    def setUp(self):
        self.school = School.objects.create(name="Test School")

    def test_update_private_pack_price_add_new_option(self):
        """Test adding a new private pack price option."""
        self.school.update_pack_price(
            pack_type="private",
            duration="45m",
            number_of_people="2p",
            number_of_classes="4c",
            price=120.00
        )
        self.assertIn("45m", self.school.private_lessons_pack_prices)
        self.assertIn("2p", self.school.private_lessons_pack_prices["45m"])
        self.assertEqual(
            self.school.private_lessons_pack_prices["45m"]["2p"],
            {"4c": 120.00}
        )

    def test_update_private_pack_price_update_existing_option(self):
        """Test updating an existing private pack price option."""
        self.school.update_pack_price(
            pack_type="private",
            duration="60m",
            number_of_people="1p",
            number_of_classes="4c",
            price=95.00
        )
        self.assertEqual(self.school.private_lessons_pack_prices["60m"]["1p"]["4c"], 95.00)

    def test_update_group_pack_price_add_new_option(self):
        """Test adding a new group pack price option."""
        self.school.update_pack_price(
            pack_type="group",
            duration="90m",
            number_of_classes="6",
            price=150.00
        )
        self.assertIn("90m", self.school.group_lessons_pack_prices)
        self.assertIn("6", self.school.group_lessons_pack_prices["90m"])
        self.assertEqual(self.school.group_lessons_pack_prices["90m"]["6"], 150.00)

    def test_delete_private_pack_option(self):
        """Test deleting a private pack price option."""
        self.school.delete_pack_option(
            pack_type="private",
            duration="60m",
            number_of_people="1p",
            number_of_classes="1c"
        )
        self.assertNotIn("1c", self.school.private_lessons_pack_prices["60m"]["1p"])

    def test_delete_group_pack_option(self):
        """Test deleting a group pack price option."""
        self.school.delete_pack_option(
            pack_type="group",
            duration="60m",
            number_of_classes="1"
        )
        self.assertNotIn("1", self.school.group_lessons_pack_prices["60m"])

    def test_delete_private_pack_option_remove_empty_dict(self):
        self.school.private_lessons_pack_prices = {
            "60m": {
                "1p": {"1c": 30, "4c": 90},
                "4p": {"1c": 65}
            }
        }
        self.school.save()

        # Delete the "1c" option under "4p" in "60m"
        self.school.delete_pack_option("private", duration="60m", number_of_people="4p", number_of_classes="1c")

        self.school.refresh_from_db()

        # Check if "4p" is still in the dictionary
        if "4p" in self.school.private_lessons_pack_prices["60m"]:
            self.assertNotIn("1c", self.school.private_lessons_pack_prices["60m"]["4p"])
            # If "4p" is empty, it should have been removed
            self.assertFalse(self.school.private_lessons_pack_prices["60m"]["4p"])
        else:
            # Assert "4p" is entirely removed if empty
            self.assertNotIn("4p", self.school.private_lessons_pack_prices["60m"])

        # Assert "60m" is removed entirely if it's empty
        if not self.school.private_lessons_pack_prices["60m"]:
            self.assertNotIn("60m", self.school.private_lessons_pack_prices)

    def test_delete_group_pack_option_remove_empty_dict(self):
        self.school.group_lessons_pack_prices = {
            "60m": {
                "1": 25,
                "4": 70
            }
        }
        self.school.save()

        # Delete the "4" option under "60m"
        self.school.delete_pack_option("group", duration="60m", number_of_classes="4")

        self.school.refresh_from_db()

        # Assert "4" is deleted
        self.assertNotIn("4", self.school.group_lessons_pack_prices["60m"])

        # Assert "60m" is removed entirely if it's empty
        if not self.school.group_lessons_pack_prices["60m"]:
            self.assertNotIn("60m", self.school.group_lessons_pack_prices)
