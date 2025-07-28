# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a data repository for the AthTech Challenge 2025 hackathon, containing athletics data from the 26th European Athletics Championships held in Rome 2024. The repository contains no executable code - it's purely a data repository with JSON, CSV, and PDF files.

## Data Structure

The repository contains three main data sources:

### 1. Competition Results (`Rome2024.json`)
- Complete results from every heat, semi-final and final
- Includes reaction times, rankings, athlete details
- Contains events from June 7-12, 2024 at Stadio Olimpico
- Structure: Array of events with nested results for each athlete

### 2. Athlete Profiles (`athletes/` directory)
- Individual JSON files for each participating athlete or relay team
- File naming convention: `{tpAthleteId}.json`
- Contains athlete metadata (nationality, accomplishments, past results)
- Historical data filtered to show only results up to June 2024

### 3. Live Tracking Data (`isolynx/` directory)
- Real-time position and acceleration data from IsoLynx system
- CSV files with 0.1-second sampling intervals during races
- File naming convention: `{eventCode},{roundType},{heatNumber},{eventName}.IsoTrack.csv`
- Contains columns: Time, X/Y coordinates, Speed, Acceleration, Distance, PathDistance, ToRail for each athlete

### 4. Event Schedule (`TIMETABLE-DEF-EN.pdf`)
- PDF calendar showing event times (not included in results JSON)

## Data Sources and Attribution

- Competition results: European Athletics Championships Rome 2024
- Athlete profiles: Provided by [Tilastopaja](https://www.tilastopaja.info/) via API
- Live tracking data: Provided by [Matsport](https://www.matsport.com/) using IsoLynx system

## Working with This Data

Since this is a data-only repository with no build system or dependencies:

- No package.json, requirements.txt, or build commands exist
- Data can be analyzed using any language/framework (Python, JavaScript, R, etc.)
- JSON files can be parsed directly
- CSV files follow standard format with headers
- Consider the data structure when writing analysis code

## Event Code Reference

The IsoLynx CSV files use numeric event codes in their filenames. Common patterns:
- Sprint events (100m, 200m, 400m): codes 14, 214 (Men's 400m, Women's 400m)
- Middle distance (800m, 1500m): codes 20, 24, 220, 224
- Distance events (5000m, 10000m): codes 34, 36, 234, 236
- Hurdles: codes 82, 282 (Men's 400m hurdles, Women's 400m hurdles)
- Steeplechase: codes 70, 270
- Relays: codes 180, 184, 380, 384, 400 (4x100m, 4x400m, Mixed 4x400m)
- Multi-events: codes 807, 910 (Heptathlon, Decathlon)

Round types: 1=Heats, 3=Semi-finals, 5=Finals, 6=Multi-event

## Data Integrity Notes

- All data is from the official European Championships
- Athlete data is filtered to show only pre-competition results
- Some IsoLynx files may have duplicate entries (numbered with "(02)", "(03)" etc.)
- The repository may be updated with additional data as it becomes available