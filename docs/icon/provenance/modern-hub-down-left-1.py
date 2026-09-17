"""Reproduce the approved modern hub with every legal facing set to east."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_down_left import render
render('modern')
