"""Tests for tools/vendor_sgj.py. Run from the repo root:
    python3 -I -m unittest tests/test_vendor.py
"""
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "tools", "vendor_sgj.py")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class VendorTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.src = os.path.join(root, "src")
        self.dest = os.path.join(root, "out", "SGJ")
        self.files = os.path.join(root, "files.txt")
        self.patches = os.path.join(root, "patches")
        os.makedirs(self.patches)
        write(os.path.join(self.src, "SharpiesGearJudge_Forever.toc"),
              "## Interface: 16001\n## Version: 3.3.2-Forever\nInit.lua\n")
        write(os.path.join(self.src, "LICENSE"), "MIT License\n\nCopyright (c) 2025 Supersharpie\n")
        write(os.path.join(self.src, "Libs", "LibStub", "LibStub.lua"),
              "local LIBSTUB_MAJOR, LIBSTUB_MINOR = \"LibStub\", 2\n")
        write(os.path.join(self.src, "Init.lua"), textwrap.dedent("""\
            SharpiesGearJudgeDB = SharpiesGearJudgeDB or {}
            SGJ_Settings = SGJ_Settings or {}
            local addonName, MSC = ...
            _G[addonName] = MSC
            local x = MySGJ_SettingsX
            """))
        write(os.path.join(self.src, "Helpers.lua"), textwrap.dedent("""\
            local _, MSC = ...
            function MSC.Mode() return SGJ_Settings.Mode end
            function MSC.Pack(...)
                local a, b = ...
                return a, b
            end
            """))
        write(os.path.join(self.src, "WhatsNew.lua"), "local addonName, MSC = ...\n")
        write(os.path.join(self.src, "AddonPanel.lua"), "local addonName, MSC = ...\n")
        write(self.files, "# engine files\nLibs\\LibStub\\LibStub.lua\nInit.lua\nHelpers.lua\n")

    def tearDown(self):
        self.tmp.cleanup()

    def run_vendor(self, ref="abc123"):
        return subprocess.run(
            [sys.executable, "-I", SCRIPT, "--ref", ref, "--src", self.src, "--dest", self.dest,
             "--files", self.files, "--patches", self.patches],
            capture_output=True, text=True)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_vararg_header_rewritten(self):
        self.assert_ok(self.run_vendor())
        self.assertIn('local addonName, MSC = "RXPGuides", RXP_SGJ_NS\n', read(os.path.join(self.dest, "Init.lua")))
        helpers = read(os.path.join(self.dest, "Helpers.lua"))
        self.assertIn('local _, MSC = "RXPGuides", RXP_SGJ_NS\n', helpers)
        # varargs inside functions are untouched
        self.assertIn("    local a, b = ...\n", helpers)

    def test_unknown_vararg_form_fails(self):
        write(os.path.join(self.src, "Helpers.lua"), "local name, ns, extra = ...\n")
        result = self.run_vendor()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Helpers.lua:1", result.stderr)

    def test_savedvariables_renamed(self):
        self.assert_ok(self.run_vendor())
        init = read(os.path.join(self.dest, "Init.lua"))
        self.assertIn("RXP_SGJ_DB = RXP_SGJ_DB or {}", init)
        self.assertIn("RXP_SGJ_Settings = RXP_SGJ_Settings or {}", init)
        self.assertIn("MySGJ_SettingsX", init)
        self.assertNotIn("SharpiesGearJudgeDB", init)
        self.assertIn("RXP_SGJ_Settings.Mode", read(os.path.join(self.dest, "Helpers.lua")))

    def test_global_addon_table_not_overwritten(self):
        self.assert_ok(self.run_vendor())
        init = read(os.path.join(self.dest, "Init.lua"))
        self.assertIn("-- vendor: removed _G[addonName] = MSC", init)
        self.assertNotRegex(init, r"(?m)^_G\[addonName\]")

    def test_guard_prepended_except_libs(self):
        self.assert_ok(self.run_vendor())
        guard = "if RXP_SGJ_DISABLED then return end\n"
        self.assertTrue(read(os.path.join(self.dest, "Init.lua")).startswith(guard))
        self.assertTrue(read(os.path.join(self.dest, "Helpers.lua")).startswith(guard))
        self.assertFalse(read(os.path.join(self.dest, "Libs", "LibStub", "LibStub.lua")).startswith(guard))

    def test_excluded_files_absent(self):
        self.assert_ok(self.run_vendor())
        self.assertFalse(os.path.exists(os.path.join(self.dest, "WhatsNew.lua")))
        self.assertFalse(os.path.exists(os.path.join(self.dest, "AddonPanel.lua")))

    def test_xml_lists_files_in_order(self):
        self.assert_ok(self.run_vendor())
        xml = read(os.path.join(self.dest, "sgj.xml"))
        a = xml.index('<Script file="SGJ\\Libs\\LibStub\\LibStub.lua"/>')
        b = xml.index('<Script file="SGJ\\Init.lua"/>')
        c = xml.index('<Script file="SGJ\\Helpers.lua"/>')
        self.assertTrue(a < b < c)

    def test_patch_applied(self):
        write(os.path.join(self.patches, "0001-mode.patch"), textwrap.dedent("""\
            --- a/Helpers.lua
            +++ b/Helpers.lua
            @@ -1,4 +1,4 @@
             if RXP_SGJ_DISABLED then return end
             local _, MSC = "RXPGuides", RXP_SGJ_NS
            -function MSC.Mode() return RXP_SGJ_Settings.Mode end
            +function MSC.Mode() return "AUTO" end
             function MSC.Pack(...)
            """))
        self.assert_ok(self.run_vendor())
        self.assertIn('function MSC.Mode() return "AUTO" end', read(os.path.join(self.dest, "Helpers.lua")))

    def test_patch_failure_aborts(self):
        write(os.path.join(self.dest, "marker.txt"), "old\n")
        write(os.path.join(self.patches, "0001-bad.patch"), textwrap.dedent("""\
            --- a/Helpers.lua
            +++ b/Helpers.lua
            @@ -1,1 +1,1 @@
            -this line does not exist
            +replacement
            """))
        result = self.run_vendor()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("0001-bad.patch", result.stderr)
        self.assertEqual(read(os.path.join(self.dest, "marker.txt")), "old\n")

    def test_upstream_file(self):
        self.assert_ok(self.run_vendor(ref="f285a2b"))
        upstream = read(os.path.join(self.dest, "UPSTREAM"))
        self.assertIn("commit=f285a2b", upstream)
        self.assertIn("version=3.3.2-Forever", upstream)
        self.assertIn("Copyright (c) 2025 Supersharpie", read(os.path.join(self.dest, "LICENSE")))

    def test_crlf_sources_normalized(self):
        with open(os.path.join(self.src, "Helpers.lua"), "w", encoding="utf-8", newline="") as f:
            f.write("local _, MSC = ...\r\nlocal y = 1\r\n")
        self.assert_ok(self.run_vendor())
        with open(os.path.join(self.dest, "Helpers.lua"), "rb") as f:
            self.assertNotIn(b"\r", f.read())


    def test_version_file_written_and_loaded_first(self):
        self.assert_ok(self.run_vendor(ref="f285a2b"))
        version = read(os.path.join(self.dest, "Version.lua"))
        self.assertIn('RXP_SGJ_VERSION = "3.3.2-Forever"', version)
        self.assertIn('RXP_SGJ_COMMIT = "f285a2b"', version)
        xml = read(os.path.join(self.dest, "sgj.xml"))
        self.assertLess(xml.index('SGJ\\Version.lua'), xml.index('SGJ\\Libs\\LibStub\\LibStub.lua'))


    def test_textures_copied_and_asset_paths_rewritten(self):
        os.makedirs(os.path.join(self.src, "Textures"), exist_ok=True)
        with open(os.path.join(self.src, "Textures", "Upgrade.png"), "wb") as f:
            f.write(b"\x89PNG fake")
        write(os.path.join(self.src, "Helpers.lua"),
              'local _, MSC = ...\n'
              'local A = "Interface\\\\AddOns\\\\SharpiesGearJudge\\\\Textures\\\\Upgrade.png"\n'
              'local B = "Interface/AddOns/SharpiesGearJudge/Textures/"\n')
        with open(self.files, "a", encoding="utf-8") as f:
            f.write("Textures\\Upgrade.png\n")
        self.assert_ok(self.run_vendor())
        with open(os.path.join(self.dest, "Textures", "Upgrade.png"), "rb") as f:
            self.assertEqual(f.read(), b"\x89PNG fake")
        helpers = read(os.path.join(self.dest, "Helpers.lua"))
        self.assertIn('"Interface\\\\AddOns\\\\RXPGuides\\\\SGJ\\\\Textures\\\\Upgrade.png"', helpers)
        self.assertIn('"Interface/AddOns/RXPGuides/SGJ/Textures/"', helpers)
        self.assertNotIn("SharpiesGearJudge", helpers)
        self.assertNotIn("Textures", read(os.path.join(self.dest, "sgj.xml")))

    def test_real_file_list_ships_every_texture(self):
        listed = set(read(os.path.join(REPO, "tools", "sgj_files.txt")).replace("\\", "/").split("\n"))
        for name in ("Upgrade.png", "Downgrade.png", "Ring_BG.tga", "Ring_Fill.tga", "Ring_Rune.tga",
                     "Ring_Sun.tga", "Ring_Swirl.tga", "Druid.tga", "Warrior.tga"):
            self.assertIn("Textures/" + name, listed)

    def test_committed_engine_has_no_standalone_asset_paths(self):
        for dirpath, _, names in os.walk(os.path.join(REPO, "SGJ")):
            for name in names:
                if name.endswith(".lua"):
                    text = read(os.path.join(dirpath, name))
                    self.assertNotRegex(text, r"AddOns[\\/]+SharpiesGearJudge", os.path.join(dirpath, name))


if __name__ == "__main__":
    unittest.main()
