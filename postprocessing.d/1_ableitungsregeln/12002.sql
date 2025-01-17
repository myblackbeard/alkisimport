SET client_encoding TO 'UTF8';
SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

--
-- Lagebezeichnung mit Hausnummer (12002)
--

SELECT 'Lagebezeichnungen mit Hausnummer werden verarbeitet.';



REFRESH MATERIALIZED VIEW ax_gebaeude_unnested;
REFRESH MATERIALIZED VIEW ax_turm_unnested;
REFRESH MATERIALIZED VIEW ax_flurstueck_unnested;


-- mit Hausnummer, Ortsteil
SELECT ' Ortsteil verarbeitet.';
INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
	o.gml_id,
	'Gebäude' AS thema,
	'ax_lagebezeichnungmithausnummer' AS layer,
	t.wkb_geometry AS point,
	schriftinhalt AS text,
	coalesce(t.signaturnummer,'4160') AS signaturnummer,
	drehwinkel, horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung,
	coalesce(t.advstandardmodell||t.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell) AS modell
FROM ax_lagebezeichnungmithausnummer o
JOIN ap_pto_unnested t ON o.gml_id = t.dientzurdarstellungvon_unnested AND t.endet IS NULL AND t.art='Ort'
WHERE coalesce(schriftinhalt,'')<>'' AND o.endet IS NULL;

ANALYZE ax_lagebezeichnungmithausnummer;
ANALYZE ax_lagebezeichnungohnehausnummer;

-- mit Hausnummer (bezieht sich auf Gebäude, Turm oder Flurstück)
SELECT ' Gebäudehausnummern werden verarbeitet.';

CREATE TEMPORARY TABLE po_zeigtauf_hausnummer(
	zeigtauf character(16),
	wkb_geometry GEOMETRY,
	prefix varchar
);
CREATE INDEX po_zeigtauf_hausnummer_zeigtauf ON po_zeigtauf_hausnummer(zeigtauf);

INSERT INTO po_zeigtauf_hausnummer
	SELECT
		zeigtauf, wkb_geometry, prefix
	FROM (
		SELECT
			unnest(zeigtauf) AS zeigtauf, wkb_geometry, '' AS prefix
		FROM ax_turm_unnested z
		JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = z.zeigtAuf_unnested AND lmh.endet IS NULL
		WHERE z.endet IS NULL
	) AS z;

ANALYZE po_zeigtauf_hausnummer;

INSERT INTO po_zeigtauf_hausnummer
	SELECT
		zeigtauf, wkb_geometry, prefix
	FROM (
		SELECT
			unnest(zeigtauf) AS zeigtauf, wkb_geometry, '' AS prefix
		FROM ax_gebaeude_unnested z
		JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = z.zeigtAuf_unnested AND lmh.endet IS NULL
		WHERE z.endet IS NULL
	) AS z
	WHERE NOT EXISTS (SELECT h.zeigtauf FROM po_zeigtauf_hausnummer h WHERE h.zeigtauf=z.zeigtauf);

ANALYZE po_zeigtauf_hausnummer;

INSERT INTO po_zeigtauf_hausnummer
	SELECT
		zeigtauf, wkb_geometry, prefix
	FROM (
		SELECT
			unnest(zeigtauf) AS zeigtauf, wkb_geometry, 'HsNr. ' AS prefix
		FROM ax_flurstueck_unnested z
		JOIN ax_lagebezeichnungmithausnummer lmh ON lmh.gml_id = z.zeigtAuf_unnested AND lmh.endet IS NULL
		WHERE z.endet IS NULL
	) AS z
	WHERE NOT EXISTS (SELECT h.zeigtauf FROM po_zeigtauf_hausnummer h WHERE h.zeigtauf=z.zeigtauf);

ANALYZE po_zeigtauf_hausnummer;

-- Kommt in Bayern auch ohne zeigtAuf Turm/Gebäude/Flurstück vor
INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ax_lagebezeichnungmithausnummer' AS layer,
	(po).p AS point,
	text, signaturnummer,
	(po).a AS drehwinkel,
	horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung, modell
FROM (
	SELECT
		o.gml_id,
		alkis_pnr3002(o.gml_id, tx.wkb_geometry, drehwinkel, o.land, o.regierungsbezirk, o.kreis, o.gemeinde, o.lage, gt.wkb_geometry) AS po,
		coalesce(tx.schriftinhalt,coalesce(gt.prefix, '')||o.hausnummer) AS text,
		coalesce(d.signaturnummer,tx.signaturnummer,'4070') AS signaturnummer,
		horizontaleausrichtung, vertikaleausrichtung, skalierung, fontsperrung,
		coalesce(tx.advstandardmodell||tx.sonstigesmodell,o.advstandardmodell||o.sonstigesmodell) AS modell
	FROM ax_lagebezeichnungmithausnummer o
	LEFT OUTER JOIN po_zeigtauf_hausnummer gt ON o.gml_id=gt.zeigtauf
	LEFT OUTER JOIN ap_pto_unnested tx ON o.gml_id = tx.dientzurdarstellungvon_unnested AND tx.endet IS NULL AND tx.art='HNR'
	LEFT OUTER JOIN ap_darstellung_unnested d ON o.gml_id = d.dientzurdarstellungvon_unnested AND d.endet IS NULL AND d.art='HNR'
	WHERE o.endet IS NULL AND (gt.zeigtauf IS NOT NULL OR o.gml_id LIKE 'DEBY%')
) AS foo
WHERE text IS NOT NULL;
