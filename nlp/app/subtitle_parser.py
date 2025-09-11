import re
import os
import subprocess
import logging
from typing import List, Dict

logger = logging.getLogger(__name__)

async def parse_subtitle_file(file_path: str) -> List[Dict]:
    """Parse subtitle file and return list of subtitle entries with timestamps"""
    
    file_ext = os.path.splitext(file_path)[1].lower()
    
    if file_ext in ['.srt', '.vtt']:
        # Direct subtitle files
        return await parse_subtitle_text_file(file_path)
    elif file_ext in ['.mp4', '.mkv', '.avi']:
        # Video files - extract subtitles using FFmpeg
        return await extract_subtitles_from_video(file_path)
    else:
        logger.warning(f"Unsupported file type: {file_ext}")
        return []

async def parse_subtitle_text_file(file_path: str) -> List[Dict]:
    """Parse .srt or .vtt subtitle files"""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        logger.error(f"Error reading file {file_path}: {e}")
        return []
    
    file_ext = os.path.splitext(file_path)[1].lower()
    
    if file_ext == '.srt':
        return parse_srt_content(content)
    elif file_ext == '.vtt':
        return parse_vtt_content(content)
    
    return []

def parse_srt_content(content: str) -> List[Dict]:
    """Parse SRT subtitle content"""
    entries = []
    
    # SRT format: number, timestamp, text, blank line
    pattern = r'(\d+)\s*\n(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})\s*\n(.*?)(?=\n\s*\n|\n\s*\d+\s*\n|\Z)'
    
    matches = re.findall(pattern, content, re.DOTALL | re.MULTILINE)
    
    for match in matches:
        number, start_time, end_time, text = match
        
        # Clean up text
        text = re.sub(r'<[^>]+>', '', text)  # Remove HTML tags
        text = text.replace('\n', ' ').strip()
        
        if text:
            entries.append({
                "number": int(number),
                "start_time": convert_srt_time_to_seconds(start_time),
                "end_time": convert_srt_time_to_seconds(end_time),
                "text": text
            })
    
    return entries

def parse_vtt_content(content: str) -> List[Dict]:
    """Parse VTT subtitle content"""
    entries = []
    
    # VTT format: timestamp, text, blank line
    pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\s*\n(.*?)(?=\n\s*\n|\n\s*\d{2}:\d{2}:\d{2}|\Z)'
    
    matches = re.findall(pattern, content, re.DOTALL | re.MULTILINE)
    
    for i, match in enumerate(matches):
        start_time, end_time, text = match
        
        # Clean up text
        text = re.sub(r'<[^>]+>', '', text)  # Remove HTML tags
        text = text.replace('\n', ' ').strip()
        
        if text:
            entries.append({
                "number": i + 1,
                "start_time": convert_vtt_time_to_seconds(start_time),
                "end_time": convert_vtt_time_to_seconds(end_time),
                "text": text
            })
    
    return entries

async def extract_subtitles_from_video(file_path: str) -> List[Dict]:
    """Extract subtitles from video file using FFmpeg"""
    try:
        # First, check if video has subtitle streams
        cmd = [
            'ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_streams',
            '-select_streams', 's', file_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.warning(f"No subtitle streams found in {file_path}")
            return []
        
        # Extract first subtitle stream to SRT format
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.srt', delete=False) as temp_file:
            temp_path = temp_file.name
        
        extract_cmd = [
            'ffmpeg', '-i', file_path, '-map', '0:s:0', '-c:s', 'srt', temp_path, '-y'
        ]
        
        extract_result = subprocess.run(extract_cmd, capture_output=True, text=True)
        
        if extract_result.returncode == 0:
            # Parse extracted SRT file
            entries = await parse_subtitle_text_file(temp_path)
            os.unlink(temp_path)  # Clean up temp file
            return entries
        else:
            logger.warning(f"Failed to extract subtitles from {file_path}: {extract_result.stderr}")
            return []
            
    except FileNotFoundError:
        logger.error("FFmpeg not found. Please install FFmpeg to process video files.")
        return []
    except Exception as e:
        logger.error(f"Error extracting subtitles from {file_path}: {e}")
        return []

def convert_srt_time_to_seconds(time_str: str) -> str:
    """Convert SRT timestamp to seconds format"""
    # Convert from HH:MM:SS,mmm to HH:MM:SS.mmm
    return time_str.replace(',', '.')

def convert_vtt_time_to_seconds(time_str: str) -> str:
    """Convert VTT timestamp to seconds format (already in correct format)"""
    return time_str