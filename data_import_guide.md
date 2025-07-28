# Data Import Guide for Athletics Database

This guide explains how to populate the SQLite database with data from the Rome 2024 European Championships dataset.

## Overview

The database schema supports three main data sources:
1. **Competition Results** (`Rome2024.json`) - Main results data
2. **Athlete Profiles** (`athletes/*.json`) - Historical athlete data  
3. **Tracking Data** (`isolynx/*.csv`) - Real-time position tracking

## Import Order

**IMPORTANT**: Follow this exact order to maintain referential integrity:

1. `competitions` table
2. `events` table  
3. `athletes` table
4. `rounds` table
5. `results` table
6. `athlete_accomplishments` table
7. `tracking_sessions` table
8. `tracking_participants` table
9. `tracking_data` table

## 1. Competition Data Import

### From `Rome2024.json`

```sql
-- Insert the main competition
INSERT INTO competitions (comp_id, comp_name, comp_type, country, city, arena, start_date, end_date)
VALUES (13075167, '26th European Athletics Championships', 'Outdoor', 'ITA', 'Roma', 'Stadio Olimpico', '2024-06-07', '2024-06-12');

-- Extract unique events from the JSON structure
-- Example for Men's 100m:
INSERT INTO events (event_code, event_name, gender, age_group, indoor_outdoor)
VALUES (40, '100m', 'M', 'Senior', 'Outdoor');
```

### JSON Processing Notes

- Parse the main JSON object to get competition metadata
- Iterate through the `events` array
- For each event, extract: `eventCode`, `eventName`, `gender`, `ageGroup`, `indoorOutdoor`
- Create unique combinations in the `events` table

## 2. Athletes Import

### From `Rome2024.json` Results

```sql
-- Extract athletes from results within each event
INSERT INTO athletes (to_id, wa_id, first_name, last_name, full_name, date_of_birth, nationality, club)
SELECT DISTINCT 
    toID,
    WAID,
    firstname,
    lastname,
    athlete,
    DOB,
    nation,
    club
FROM json_results_data;
```

### From `athletes/*.json` Files

```sql
-- Merge additional athlete data
UPDATE athletes SET 
    tp_athlete_id = ?,
    birth_year = ?,
    height = ?,
    weight = ?,
    birth_place = ?
WHERE to_id = ? OR tp_athlete_id = ?;
```

### Athlete Processing Notes

- Primary key is auto-increment `athlete_id`
- `to_id` from competition results is the main identifier
- `tp_athlete_id` from athlete files provides additional data
- Handle missing/null values appropriately
- Some athlete files may not have corresponding competition results

## 3. Rounds Import

### From `Rome2024.json`

```sql
INSERT INTO rounds (comp_id, event_id, round_name, round_type, heat_number, heat_name, 
                   list_name, heat_count, date, results_version, wind)
SELECT 
    13075167, -- comp_id
    (SELECT event_id FROM events WHERE event_code = ? AND gender = ?), -- event_id
    roundName,
    CASE roundName 
        WHEN 'Heat' THEN 1
        WHEN 'Semi-Final' THEN 3
        WHEN 'Final' THEN 5
        ELSE 1
    END,
    heatNumber,
    heatName,
    listName,
    heatCount,
    date,
    resultsVersion,
    wind
FROM json_event_data;
```

## 4. Results Import

### From `Rome2024.json`

```sql
INSERT INTO results (round_id, athlete_id, rank, best_performance, wind, record_flags, 
                    personal_flags, reaction_time, qualified)
SELECT 
    ?,  -- round_id from previous insert
    (SELECT athlete_id FROM athletes WHERE to_id = ?), -- athlete_id
    rank,
    bestPerformance,
    wind,
    recordFlags,
    personalFlags,
    CAST(reactiontime AS REAL),
    qualified
FROM json_results_data;
```

## 5. Athlete Accomplishments Import

### From `athletes/*.json` Files

```sql
INSERT INTO athlete_accomplishments (athlete_id, event_code, rank, age_group, competition, season, indoor)
SELECT 
    (SELECT athlete_id FROM athletes WHERE tp_athlete_id = ?),
    eventCode,
    rank,
    ageGroup,
    competition,
    season,
    COALESCE(indoor, FALSE)
FROM json_accomplishments_data;
```

## 6. Tracking Data Import

### Step 1: Parse CSV Filenames

IsoLynx files follow the pattern: `{eventCode},{roundType},{heatNumber},{description}.IsoTrack.csv`

Example: `"14,1,1,400m Men R1 H1.IsoTrack.csv"`
- eventCode: 14
- roundType: 1 (Heat)
- heatNumber: 1
- description: "400m Men R1 H1"

### Step 2: Create Tracking Sessions

```sql
INSERT INTO tracking_sessions (round_id, file_name, event_code, round_type, heat_number, event_description)
VALUES (
    (SELECT round_id FROM rounds r 
     JOIN events e ON r.event_id = e.event_id 
     WHERE e.event_code = ? AND r.round_type = ? AND r.heat_number = ?),
    ?,  -- file_name
    ?,  -- event_code
    ?,  -- round_type  
    ?,  -- heat_number
    ?   -- event_description
);
```

### Step 3: Parse CSV Headers

CSV structure:
- Row 1: Athlete IDs (ID 1193, ID 1128, etc.)
- Row 2: Athlete surnames (PETRUCCIANI, ZALEWSKI, etc.)
- Row 3: Column headers (Time, X, Y, Speed, Accel, Distance, PathDist, ToRail) repeated for each athlete

```sql
-- For each athlete found in the CSV headers
INSERT INTO tracking_participants (session_id, athlete_id, athlete_surname, participant_order)
VALUES (
    ?,  -- session_id from previous insert
    (SELECT athlete_id FROM athletes WHERE last_name = ? COLLATE NOCASE),  -- May be NULL
    ?,  -- athlete_surname from CSV
    ?   -- participant_order (1, 2, 3, etc.)
);
```

### Step 4: Import Tracking Data Points

```sql
-- For each data row in the CSV (starting from row 4)
INSERT INTO tracking_data (participant_id, time_seconds, x_coordinate, y_coordinate, 
                          speed, acceleration, distance, path_distance, to_rail)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
```

### CSV Processing Notes

- Each athlete has 8 columns: Time, X, Y, Speed, Accel, Distance, PathDist, ToRail
- Time format: "MM:SS.mmm" (convert to seconds as REAL)
- Handle missing/zero values appropriately
- Some files have duplicate versions (e.g., "(02)", "(03)")

## Data Quality Considerations

### Handling Missing Data

- Use NULL for missing numeric values
- Use empty string for missing text values where appropriate
- Set boolean fields to FALSE when NULL

### Data Validation

```sql
-- Check for athletes without results
SELECT * FROM athletes a 
LEFT JOIN results r ON a.athlete_id = r.athlete_id 
WHERE r.athlete_id IS NULL;

-- Check for orphaned results
SELECT * FROM results r 
LEFT JOIN athletes a ON r.athlete_id = a.athlete_id 
WHERE a.athlete_id IS NULL;

-- Validate tracking data completeness
SELECT 
    ts.file_name,
    COUNT(DISTINCT tp.participant_id) as athletes,
    COUNT(td.data_id) as data_points,
    MIN(td.time_seconds) as min_time,
    MAX(td.time_seconds) as max_time
FROM tracking_sessions ts
LEFT JOIN tracking_participants tp ON ts.session_id = tp.session_id
LEFT JOIN tracking_data td ON tp.participant_id = td.participant_id
GROUP BY ts.session_id;
```

## Sample ETL Script Structure

```python
import sqlite3
import json
import csv
import os
from datetime import datetime

def import_athletics_data():
    # 1. Create database and tables
    conn = sqlite3.connect('athletics.db')
    conn.executescript(open('athletics_database_schema.sql').read())
    
    # 2. Import competition data
    import_competition_data(conn)
    
    # 3. Import athlete data
    import_athlete_data(conn)
    
    # 4. Import tracking data
    import_tracking_data(conn)
    
    conn.close()

def import_competition_data(conn):
    # Load and process Rome2024.json
    pass

def import_athlete_data(conn):
    # Process athletes/*.json files
    pass

def import_tracking_data(conn):
    # Process isolynx/*.csv files
    pass
```

## Performance Tips

1. Use transactions for bulk imports
2. Disable foreign key checks during import, re-enable after
3. Create indexes after data import for better performance
4. Use prepared statements for repeated insertions
5. Consider using CSV import functionality for large datasets

```sql
-- Disable foreign keys during import
PRAGMA foreign_keys = OFF;

-- Your import operations here...

-- Re-enable foreign keys
PRAGMA foreign_keys = ON;
```