SET client_encoding TO 'UTF8';
SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

--
-- Tatsächliche Nutzung
--

SELECT 'Tatsächliche Nutzungen werden verarbeitet.';

--
-- Wohnbauflächen
--

-- Wohnbauflächen, Flächen
INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Wohnbauflächen' AS thema,
	'ax_wohnbauflaeche' AS layer,
	st_multi(wkb_geometry) AS polygon,
	25151401 AS signaturnummer,
	advstandardmodell||sonstigesmodell
FROM ax_wohnbauflaeche
WHERE endet IS NULL;

INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
	gml_id,
	'Wohnbauflächen' AS thema,
	'ax_wohnbauflaeche' AS layer,
	point,
	text,
	signaturnummer,
	drehwinkel, horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung, modell
FROM (
	SELECT
		o.gml_id,
		coalesce(t.wkb_geometry,st_centroid(o.wkb_geometry)) AS point,
		coalesce(t.schriftinhalt,o.name) AS text,
		coalesce(d.signaturnummer,t.signaturnummer,'4141') AS signaturnummer,
		drehwinkel, horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung,
		coalesce(t.advstandardmodell||t.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell) AS modell
	FROM ax_wohnbauflaeche o
	LEFT OUTER JOIN ap_pto_unnested t ON o.gml_id = t.dientzurdarstellungvon_unnested AND t.art='NAM' AND t.endet IS NULL
	LEFT OUTER JOIN ap_darstellung_unnested d ON o.gml_id = d.dientzurdarstellungvon_unnested AND d.art='NAM' AND d.endet IS NULL
	WHERE o.endet IS NULL
) AS n WHERE NOT text IS NULL;
