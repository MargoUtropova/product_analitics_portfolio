CREATE OR REPLACE VIEW rfm_segments_with_monetary AS
SELECT
    s.card,
    s.rfm_segment,
    m.monetary
FROM rfm_segments s
LEFT JOIN rfm_metrics m ON s.card = m.card;