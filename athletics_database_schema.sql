-- Athletics Database Schema for European Championships Rome 2024
-- Designed to store competition results, athlete profiles, and tracking data

-- ============================================================================
-- COMPETITION AND EVENT STRUCTURE
-- ============================================================================

-- Main competition information
CREATE TABLE competitions (
    comp_id INTEGER PRIMARY KEY,
    comp_name TEXT NOT NULL,
    comp_type TEXT NOT NULL, -- 'Outdoor', 'Indoor'
    country TEXT NOT NULL,
    city TEXT NOT NULL,
    arena TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

-- Event definitions (100m, 400m, etc.)
CREATE TABLE events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_code INTEGER NOT NULL,
    event_name TEXT NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('M', 'W')),
    age_group TEXT NOT NULL DEFAULT 'Senior',
    indoor_outdoor TEXT NOT NULL CHECK (indoor_outdoor IN ('Indoor', 'Outdoor')),
    UNIQUE(event_code, gender, age_group, indoor_outdoor)
);

-- Competition rounds (heats, semi-finals, finals)
CREATE TABLE rounds (
    round_id INTEGER PRIMARY KEY AUTOINCREMENT,
    comp_id INTEGER NOT NULL,
    event_id INTEGER NOT NULL,
    round_name TEXT NOT NULL, -- 'Final', 'Semi-Final', 'Heat'
    round_type INTEGER NOT NULL, -- 1=Heat, 3=Semi, 5=Final, 6=Multi-event
    heat_number INTEGER,
    heat_name TEXT,
    list_name TEXT,
    heat_count INTEGER,
    date DATE NOT NULL,
    results_version INTEGER DEFAULT 1,
    wind REAL,
    FOREIGN KEY (comp_id) REFERENCES competitions(comp_id),
    FOREIGN KEY (event_id) REFERENCES events(event_id)
);

-- ============================================================================
-- ATHLETE INFORMATION
-- ============================================================================

-- Core athlete data
CREATE TABLE athletes (
    athlete_id INTEGER PRIMARY KEY AUTOINCREMENT,
    to_id INTEGER UNIQUE, -- toID from competition results
    wa_id INTEGER, -- WAID (World Athletics ID)
    tp_athlete_id TEXT, -- Tilastopaja athlete ID
    ot_athlete_id TEXT, -- OpenTrack athlete ID
    first_name TEXT,
    last_name TEXT,
    full_name TEXT, -- Complete name as appears in results
    date_of_birth DATE,
    birth_year INTEGER,
    nationality TEXT NOT NULL,
    gender TEXT CHECK (gender IN ('M', 'W')),
    height INTEGER, -- in cm
    weight INTEGER, -- in kg
    club TEXT,
    birth_place TEXT
);

-- Athlete accomplishments/historical results
CREATE TABLE athlete_accomplishments (
    accomplishment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    athlete_id INTEGER NOT NULL,
    event_code TEXT NOT NULL, -- e.g., '100', '4x4', '4x1'
    rank TEXT, -- Can be empty string
    age_group TEXT NOT NULL,
    competition TEXT NOT NULL, -- 'EC', 'WC', etc.
    season TEXT NOT NULL,
    indoor BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (athlete_id) REFERENCES athletes(athlete_id)
);

-- ============================================================================
-- COMPETITION RESULTS
-- ============================================================================

-- Individual athlete results in each round
CREATE TABLE results (
    result_id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id INTEGER NOT NULL,
    athlete_id INTEGER NOT NULL,
    rank TEXT, -- Can be numeric or text like 'DQ', 'DNS'
    best_performance TEXT NOT NULL, -- Time/distance as string
    wind REAL,
    record_flags TEXT, -- 'WR', 'ER', 'NR', etc.
    personal_flags TEXT, -- 'PB', 'SB', etc.
    reaction_time REAL,
    qualified TEXT, -- Qualification status
    lane INTEGER, -- Lane assignment if available
    FOREIGN KEY (round_id) REFERENCES rounds(round_id),
    FOREIGN KEY (athlete_id) REFERENCES athletes(athlete_id)
);

-- ============================================================================
-- ISOLYNX TRACKING DATA
-- ============================================================================

-- Tracking sessions (one per race file)
CREATE TABLE tracking_sessions (
    session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id INTEGER NOT NULL,
    file_name TEXT NOT NULL UNIQUE,
    event_code INTEGER NOT NULL,
    round_type INTEGER NOT NULL,
    heat_number INTEGER NOT NULL,
    event_description TEXT NOT NULL,
    FOREIGN KEY (round_id) REFERENCES rounds(round_id)
);

-- Athletes participating in tracking session
CREATE TABLE tracking_participants (
    participant_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    athlete_id INTEGER, -- May be NULL if athlete not in main database
    athlete_surname TEXT NOT NULL, -- Surname from CSV header
    participant_order INTEGER NOT NULL, -- Order in CSV columns
    FOREIGN KEY (session_id) REFERENCES tracking_sessions(session_id),
    FOREIGN KEY (athlete_id) REFERENCES athletes(athlete_id),
    UNIQUE(session_id, participant_order)
);

-- Individual tracking data points
CREATE TABLE tracking_data (
    data_id INTEGER PRIMARY KEY AUTOINCREMENT,
    participant_id INTEGER NOT NULL,
    time_seconds REAL NOT NULL,
    x_coordinate REAL NOT NULL,
    y_coordinate REAL NOT NULL,
    speed REAL NOT NULL,
    acceleration REAL NOT NULL,
    distance REAL NOT NULL,
    path_distance REAL NOT NULL,
    to_rail REAL NOT NULL,
    FOREIGN KEY (participant_id) REFERENCES tracking_participants(participant_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Competition and event indexes
CREATE INDEX idx_competitions_date ON competitions(start_date, end_date);
CREATE INDEX idx_events_code_gender ON events(event_code, gender);
CREATE INDEX idx_rounds_comp_event ON rounds(comp_id, event_id);
CREATE INDEX idx_rounds_date ON rounds(date);

-- Athlete indexes
CREATE INDEX idx_athletes_to_id ON athletes(to_id);
CREATE INDEX idx_athletes_wa_id ON athletes(wa_id);
CREATE INDEX idx_athletes_tp_id ON athletes(tp_athlete_id);
CREATE INDEX idx_athletes_nationality ON athletes(nationality);
CREATE INDEX idx_athletes_name ON athletes(last_name, first_name);

-- Results indexes
CREATE INDEX idx_results_round ON results(round_id);
CREATE INDEX idx_results_athlete ON results(athlete_id);
CREATE INDEX idx_results_rank ON results(rank);

-- Tracking data indexes
CREATE INDEX idx_tracking_sessions_round ON tracking_sessions(round_id);
CREATE INDEX idx_tracking_participants_session ON tracking_participants(session_id);
CREATE INDEX idx_tracking_data_participant ON tracking_data(participant_id);
CREATE INDEX idx_tracking_data_time ON tracking_data(time_seconds);

-- Accomplishments indexes
CREATE INDEX idx_accomplishments_athlete ON athlete_accomplishments(athlete_id);
CREATE INDEX idx_accomplishments_event ON athlete_accomplishments(event_code);
CREATE INDEX idx_accomplishments_season ON athlete_accomplishments(season);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Complete results view with athlete and event information
CREATE VIEW v_complete_results AS
SELECT 
    c.comp_name,
    c.city,
    c.country,
    e.event_name,
    e.gender,
    r.round_name,
    r.heat_number,
    r.date,
    r.wind as round_wind,
    a.full_name as athlete_name,
    a.first_name,
    a.last_name,
    a.nationality,
    a.date_of_birth,
    res.rank,
    res.best_performance,
    res.wind as result_wind,
    res.reaction_time,
    res.record_flags,
    res.personal_flags,
    res.qualified
FROM results res
JOIN rounds r ON res.round_id = r.round_id
JOIN competitions c ON r.comp_id = c.comp_id
JOIN events e ON r.event_id = e.event_id
JOIN athletes a ON res.athlete_id = a.athlete_id;

-- Athlete summary view
CREATE VIEW v_athlete_summary AS
SELECT 
    a.athlete_id,
    a.full_name,
    a.first_name,
    a.last_name,
    a.nationality,
    a.date_of_birth,
    a.gender,
    COUNT(DISTINCT res.round_id) as events_competed,
    COUNT(CASE WHEN res.rank = '1' THEN 1 END) as gold_medals,
    COUNT(CASE WHEN res.rank = '2' THEN 1 END) as silver_medals,
    COUNT(CASE WHEN res.rank = '3' THEN 1 END) as bronze_medals
FROM athletes a
LEFT JOIN results res ON a.athlete_id = res.athlete_id
GROUP BY a.athlete_id;

-- Event summary view
CREATE VIEW v_event_summary AS
SELECT 
    e.event_name,
    e.gender,
    COUNT(DISTINCT r.round_id) as total_rounds,
    COUNT(DISTINCT res.athlete_id) as total_athletes,
    MIN(r.date) as first_date,
    MAX(r.date) as last_date
FROM events e
JOIN rounds r ON e.event_id = r.event_id
LEFT JOIN results res ON r.round_id = res.round_id
GROUP BY e.event_id;

-- ============================================================================
-- SAMPLE QUERIES AND USAGE NOTES
-- ============================================================================

/*
-- Example queries:

-- 1. Get all results for Men's 100m Final
SELECT * FROM v_complete_results 
WHERE event_name = '100m' AND gender = 'M' AND round_name = 'Final'
ORDER BY CAST(rank AS INTEGER);

-- 2. Find all athletes from Italy with their medal count
SELECT * FROM v_athlete_summary 
WHERE nationality = 'ITA'
ORDER BY (gold_medals + silver_medals + bronze_medals) DESC;

-- 3. Get tracking data for a specific race
SELECT 
    tp.athlete_surname,
    td.time_seconds,
    td.speed,
    td.x_coordinate,
    td.y_coordinate
FROM tracking_data td
JOIN tracking_participants tp ON td.participant_id = tp.participant_id
JOIN tracking_sessions ts ON tp.session_id = ts.session_id
WHERE ts.event_description LIKE '%400m Men Final%'
ORDER BY td.time_seconds, tp.participant_order;

-- 4. Athletes with best reaction times in sprint events
SELECT 
    a.full_name,
    a.nationality,
    e.event_name,
    res.reaction_time
FROM results res
JOIN athletes a ON res.athlete_id = a.athlete_id
JOIN rounds r ON res.round_id = r.round_id
JOIN events e ON r.event_id = e.event_id
WHERE res.reaction_time IS NOT NULL
  AND e.event_name IN ('100m', '200m', '110m Hurdles', '100m Hurdles')
ORDER BY res.reaction_time ASC
LIMIT 10;

*/