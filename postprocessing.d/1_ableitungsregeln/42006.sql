SET client_encoding TO 'UTF8';
SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

--
-- Weg (42006)
--

SELECT 'Wege werden verarbeitet.';

REFRESH MATERIALIZED VIEW ap_pto_unnested;
REFRESH MATERIALIZED VIEW ap_ppo_unnested;
REFRESH MATERIALIZED VIEW ap_lpo_unnested;
REFRESH MATERIALIZED VIEW ap_darstellung_unnested;

-- Flächen
INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Verkehr' AS thema,
	'ax_weg' AS layer,
	st_multi(wkb_geometry) AS polygon,
	2515 AS signaturnummer,
	advstandardmodell||sonstigesmodell
FROM ax_weg;

-- Symbol
INSERT INTO po_points(gml_id,thema,layer,point,drehwinkel,signaturnummer,modell)
SELECT
	gml_id,
	'Verkehr' AS thema,
	'ax_weg' AS layer,
	st_multi(point),
	drehwinkel,
	signaturnummer,
	modell
FROM (
	SELECT
		o.gml_id,
		coalesce(p.wkb_geometry,st_centroid(o.wkb_geometry)) AS point,
		coalesce(p.drehwinkel,0) AS drehwinkel,
		coalesce(
			d.signaturnummer,
			p.signaturnummer,
			CASE
			WHEN funktion IN (5220,5230) THEN '3424'
			WHEN funktion=5240           THEN '3426'
			WHEN funktion=5250           THEN '3428'
			WHEN funktion=5260           THEN '3430'
			END
		) AS signaturnummer,
		coalesce(
			p.advstandardmodell||p.sonstigesmodell||d.advstandardmodell||d.sonstigesmodell,
			o.advstandardmodell||o.sonstigesmodell
		) AS modell
	FROM ax_weg o
	LEFT OUTER JOIN ap_ppo_unnested p ON o.gml_id = p.dientzurdarstellungvon_unnested AND p.art='FKT' AND p.endet IS NULL
	LEFT OUTER JOIN ap_darstellung_unnested d ON o.gml_id = d.dientzurdarstellungvon_unnested AND d.art='FKT' AND d.endet IS NULL
	WHERE o.endet IS NULL
) AS o
WHERE NOT signaturnummer IS NULL;
