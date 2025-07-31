from __future__ import annotations

from metapkg import packages
from metapkg import targets


class LibJPEG(packages.BundledCMakePackage):
    title = "libjpeg"
    ident = "libjpeg"
    aliases = ["libjpeg-dev"]

    _server = (
        "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/"
    )

    sources = [
        {
            "url": _server + "{version}/libjpeg-turbo-{version}.tar.gz",
        },
    ]

    def get_dep_pkg_name(self) -> str:
        """Name used by pkg-config or CMake to refer to this package."""
        return "JPEG"

    def get_shlibs(self, build: targets.Build) -> list[str]:
        return ["jpeg"]
