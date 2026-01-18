"""
Image metadata extraction utilities.

Uses Pillow to read EXIF data from image files. Falls back to filesystem
timestamps when EXIF is unavailable. Returns a minimal, consistent dict.
"""

from typing import Dict, Any, Optional
from pathlib import Path
from datetime import datetime
from PIL import Image, ExifTags

def _exif_dict(img: Image.Image) -> Dict[int, Any]:
	try:
		exif = img._getexif()  # type: ignore[attr-defined]
		return exif or {}
	except Exception:
		return {}

def _find_tag(exif: Dict[int, Any], tag_name: str) -> Optional[Any]:

	for k, v in exif.items():
		name = ExifTags.TAGS.get(k)

		if name == tag_name:
			return v
		
	return None

def extract_metadata(path: str) -> Dict[str, Any]:
	"""
	Extract basic metadata from an image file.

	Parameters:
	- path: absolute or relative filesystem path to the image

	Returns:
	- dict with keys: `date_taken`, `location` (if GPS present), `source`
	"""
	p = Path(path)
	md: Dict[str, Any] = {"source": "exif"}
	date_taken: Optional[str] = None
	location: Optional[str] = None

	try:
		with Image.open(p) as img:
			ex = _exif_dict(img)
			dt = _find_tag(ex, "DateTimeOriginal") or _find_tag(ex, "DateTime")

			if isinstance(dt, str):
				# EXIF format: "YYYY:MM:DD HH:MM:SS"

				try:
					date_taken = datetime.strptime(dt, "%Y:%m:%d %H:%M:%S").isoformat()
				except Exception:
					date_taken = dt
			gps = _find_tag(ex, "GPSInfo")

			if isinstance(gps, dict) and gps:
				location = "GPS present"

	except Exception:
		md["source"] = "fs"

	if not date_taken:
		try:
			stat = p.stat()
			date_taken = datetime.fromtimestamp(stat.st_mtime).isoformat()
		except Exception:
			date_taken = None
	md["date_taken"] = date_taken
	md["location"] = location or "Unknown"
	
	return md

