const fs = require("fs");
const path = require("path");
const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const multer = require("multer");
const xlsx = require("xlsx");

function loadLocalEnv() {
  const envPath = path.join(__dirname, ".env");
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const [key, ...rest] = trimmed.split("=");
    if (!process.env[key]) process.env[key] = rest.join("=").trim();
  }
}

loadLocalEnv();

const app = express();
const PORT = process.env.PORT || 3000;

const dbConfig = {
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "",
  database: process.env.DB_NAME || "prueba",
};

const pool = new Pool(dbConfig);

app.use(cors());
app.use(express.json());
app.use(express.static("."));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
});

const toNull = (value) => {
  if (value === undefined || value === null) return null;
  if (typeof value === "string" && value.trim() === "") return null;
  return value;
};

const toIntOrNull = (value) => {
  const v = toNull(value);
  if (v === null) return null;
  const n = Number(v);
  return Number.isNaN(n) ? null : parseInt(n, 10);
};

const toNumOrNull = (value) => {
  const v = toNull(value);
  if (v === null) return null;
  const n = Number(v);
  return Number.isNaN(n) ? null : n;
};

const toStringOrNull = (value) => {
  const v = toNull(value);
  return v === null ? null : String(v);
};

function pad2(n) {
  return String(n).padStart(2, "0");
}

function excelSerialToDateTime(serial) {
  // Base de Excel (Windows): 1899-12-30
  const baseUtc = Date.UTC(1899, 11, 30);
  const ms = Math.round(Number(serial) * 24 * 60 * 60 * 1000);
  return new Date(baseUtc + ms);
}

function toPgDateOrTimestamp(value, mode = "date") {
  const v = toNull(value);
  if (v === null) return null;

  // Si viene como número serial de Excel
  if (typeof v === "number" || (typeof v === "string" && /^-?\d+(\.\d+)?$/.test(v.trim()))) {
    const num = Number(v);
    // Rango razonable de serial Excel para evitar falsos positivos (años modernos aprox)
    if (!Number.isNaN(num) && num > 20000 && num < 90000) {
      const d = excelSerialToDateTime(num);
      const yyyy = d.getUTCFullYear();
      const mm = pad2(d.getUTCMonth() + 1);
      const dd = pad2(d.getUTCDate());
      if (mode === "date") return `${yyyy}-${mm}-${dd}`;
      const hh = pad2(d.getUTCHours());
      const mi = pad2(d.getUTCMinutes());
      const ss = pad2(d.getUTCSeconds());
      return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
    }
  }

  // Si ya viene string fecha/hora, se conserva
  const txt = String(v).trim();
  return txt === "" ? null : txt;
}

const normalizeKey = (k) =>
  String(k ?? "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/\s+/g, "_");

function normalizeRowKeys(row) {
  const out = {};
  for (const [k, v] of Object.entries(row)) out[normalizeKey(k)] = v;
  return out;
}

function sheetToRows(workbook, sheetName) {
  const sheet = workbook.Sheets[sheetName];
  if (!sheet) return [];
  const raw = xlsx.utils.sheet_to_json(sheet, { defval: null });
  return raw.map(normalizeRowKeys);
}

function getWorkbookSheetMap(workbook) {
  const map = new Map();
  for (const name of workbook.SheetNames || []) {
    map.set(normalizeKey(name), name);
  }
  return map;
}

function sheetToRowsByAliases(workbook, sheetMap, aliases) {
  for (const alias of aliases) {
    const normalizedAlias = normalizeKey(alias);
    const realName = sheetMap.get(normalizedAlias);
    if (!realName) continue;
    const sheet = workbook.Sheets[realName];
    if (!sheet) continue;
    const raw = xlsx.utils.sheet_to_json(sheet, { defval: null });
    return { rows: raw.map(normalizeRowKeys), sheetName: realName };
  }
  return { rows: [], sheetName: null };
}

function countMeaningfulImportSignals(rows) {
  const has = (row, keys) => keys.some((key) => toNull(row[key]) !== null);
  let signals = 0;

  for (const r of rows.programa || []) if (has(r, ["codigo_programa", "codigo", "denominacion", "nombre", "nombre_programa"])) signals++;
  for (const r of rows.ficha || []) if (has(r, ["codigo_ficha", "ficha", "id_programa", "codigo_programa"])) signals++;
  for (const r of rows.aprendiz || []) if (has(r, ["documento", "numero_documento", "numero_de_identificacion"]) && has(r, ["nombre", "nombres", "nombre_completo", "apellidos"])) signals += 2;
  for (const r of rows.competencia || []) if (has(r, ["codigo_competencia", "competencia", "nombre_competencia", "descripcion"])) signals++;
  for (const r of rows.resultado_aprendizaje || []) if (has(r, ["codigo_resultado", "resultado", "resultado_aprendizaje", "nombre_resultado", "descripcion"])) signals++;
  for (const r of rows.juicios_evaluativos || []) if (has(r, ["juicio", "codigo_juicio", "tipo_juicio", "id_tipo_juicio"]) && has(r, ["documento", "id_matricula", "codigo_resultado", "resultado"])) signals += 3;

  return signals;
}

function normalizeTableName(name) {
  const n = normalizeKey(name);
  const aliases = {
    estado_aprendiz: ["estado_aprendiz", "estado aprendiz", "estados", "estados_aprendiz"],
    tipo_juicio: ["tipo_juicio", "tipo juicio", "tipos_juicio", "tipos juicio"],
    funcionario: ["funcionario", "funcionarios"],
    programa: ["programa", "programas"],
    ficha: ["ficha", "fichas"],
    aprendiz: ["aprendiz", "aprendices"],
    matricula: ["matricula", "matriculas", "matrícula", "matrículas"],
    competencia: ["competencia", "competencias"],
    resultado_aprendizaje: [
      "resultado_aprendizaje",
      "resultados_aprendizaje",
      "resultado aprendizaje",
      "resultados aprendizaje",
      "resultado",
      "resultados",
    ],
    juicios_evaluativos: ["juicios_evaluativos", "juicios evaluativos", "juicio", "juicios"],
  };
  for (const [table, list] of Object.entries(aliases)) {
    if (list.map(normalizeKey).includes(n)) return table;
  }
  return null;
}

function safeToken(value, fallback = "SIN_VALOR") {
  const txt = String(value ?? "")
    .trim()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/[^A-Za-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toUpperCase();
  return txt || fallback;
}

function hashId(text) {
  const s = String(text ?? "");
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h;
}

function parseEvaluationReportSheet(workbook, sheetName) {
  const sheet = workbook.Sheets[sheetName];
  if (!sheet) return null;

  const matrix = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: null });
  if (!matrix.length) return null;

  const normalizedRows = matrix.map((row) => row.map((c) => normalizeKey(c)));
  const hasAny = (row, patterns) =>
    row.some((cell) => patterns.some((p) => String(cell || "").includes(p)));

  const headerIdx = normalizedRows.findIndex((row) => {
    const rowText = row.filter(Boolean).join(" ");
    const score =
      (hasAny(row, ["tipo"]) ? 1 : 0) +
      (hasAny(row, ["numero_de_identificacion", "numero_identificacion", "documento", "identificacion"]) ? 1 : 0) +
      (hasAny(row, ["nombre", "nombres"]) ? 1 : 0) +
      (hasAny(row, ["apellidos", "apellido"]) ? 1 : 0) +
      (hasAny(row, ["competencia"]) ? 1 : 0) +
      (hasAny(row, ["resultado_de_aprendizaje", "resultado"]) ? 1 : 0) +
      (hasAny(row, ["juicio"]) ? 1 : 0);

    // Si tiene suficientes pistas de tabla de detalle, lo tomamos como encabezado.
    return score >= 5 || (rowText.includes("competencia") && rowText.includes("resultado"));
  });
  if (headerIdx === -1) return null;

  const header = normalizedRows[headerIdx];

  // Detección inteligente de columnas:
  // Usamos un set de columnas ya reclamadas para evitar que dos campos
  // apunten al mismo índice (ej. "tipo_de_identificacion" contiene tanto
  // "tipo" como "identificacion").
  const claimed = new Set();
  const indexOf = (...candidates) => {
    // Primero buscamos coincidencia exacta
    for (const c of candidates) {
      const exact = header.findIndex((h, i) => !claimed.has(i) && h === c);
      if (exact !== -1) return exact;
    }
    // Luego coincidencia parcial (includes)
    for (const c of candidates) {
      const partial = header.findIndex((h, i) => !claimed.has(i) && h.includes(c));
      if (partial !== -1) return partial;
    }
    return -1;
  };
  const claim = (...candidates) => {
    const idx = indexOf(...candidates);
    if (idx !== -1) claimed.add(idx);
    return idx;
  };

  // Orden: primero los más específicos para evitar colisiones.
  // "numero_de_identificacion" se busca ANTES que "tipo" porque ambos
  // podrían matchear con "identificacion".
  const idxDoc = claim("numero_de_identificacion", "numero_identificacion", "numero_de", "numero_documento");
  const idxTipo = claim("tipo_de_documento", "tipo_de_identificacion", "tipo_documento", "tipo");
  const idxNombre = claim("nombres", "nombre");
  const idxApellidos = claim("apellidos", "apellido");
  const idxEstado = claim("estado");
  const idxCompetencia = claim("competencia");
  const idxResultado = claim("resultado_de_aprendizaje", "resultado");
  const idxJuicio = claim("juicio_de_evaluacion", "juicio");
  const idxFecha = claim("fecha_y_hora_del_juicio", "fecha_y_hora", "fecha");
  const idxFuncionario = claim("funcionario_que_registro_el_juicio_evaluativo", "funcionario", "registrado_por");

  console.log("[PARSER] Header row:", headerIdx, "→", header);
  console.log("[PARSER] Column indices:", { idxTipo, idxDoc, idxNombre, idxApellidos, idxEstado, idxCompetencia, idxResultado, idxJuicio, idxFecha, idxFuncionario });

  const meta = {};
  for (let i = 0; i < headerIdx; i++) {
    const row = matrix[i] || [];
    // Buscar en la fila la primera celda con texto que parezca una etiqueta (clave)
    for (let c = 0; c < row.length; c++) {
      if (row[c] && typeof row[c] === "string") {
        const k = normalizeKey(row[c]).replace(/[^a-z0-9_]/g, "");
        if (k) {
          // El valor es la siguiente celda no nula
          let v = null;
          for (let nextC = c + 1; nextC < row.length; nextC++) {
            if (row[nextC] !== null && row[nextC] !== undefined && row[nextC] !== "") {
              v = row[nextC];
              break;
            }
          }
          meta[k] = v;
        }
      }
    }
  }

  console.log("[PARSER] Metadata keys:", Object.keys(meta));
  console.log("[PARSER] Metadata:", JSON.stringify(meta, null, 2));

  // Buscar ficha en la metadata con todas las variantes posibles
  const findMeta = (...keys) => {
    for (const k of keys) {
      if (meta[k] !== undefined && meta[k] !== null) return meta[k];
    }
    return null;
  };

  const fichaNum = findMeta(
    "ficha_de_caracterizacion", "ficha_caracterizacion", "codigo_de_la_ficha",
    "codigo_ficha", "ficha_no", "ficha", "numero_ficha"
  );
  const codigoFicha = String(fichaNum || "").trim() || `F-${Date.now()}`;

  const centroFormacion = String(
    findMeta("centro_de_formacion", "centro_formacion", "centro") || "Centro General"
  ).trim();

  const rawDenominacion = findMeta(
    "denominacion", "denominacion_del_programa", "programa", "nombre_programa"
  );
  const denominacionPrograma = String(rawDenominacion || centroFormacion || "Programa Importado").trim();

  const codigoPrograma =
    String(findMeta("codigo_programa", "codigo_del_programa", "codigo") || "").trim()
    || `PRG-${safeToken(denominacionPrograma).slice(0, 12)}`;

  const idFichaRaw = String(fichaNum || "").replace(/\D/g, "");
  const idFicha = idFichaRaw ? Number(idFichaRaw) : (hashId(codigoFicha) % 900000) + 100000;

  const out = {
    estado_aprendiz: [],
    tipo_juicio: [],
    funcionario: [],
    programa: [],
    ficha: [],
    aprendiz: [],
    matricula: [],
    competencia: [],
    resultado_aprendizaje: [],
    juicios_evaluativos: [],
  };

  out.programa.push({
    codigo_programa: codigoPrograma,
    denominacion: denominacionPrograma,
    version: 1,
    nivel_formacion: String(meta.nivel_de_formacion || meta.nivel_formacion || "Tecnico").trim(),
    estado: "Activo",
  });

  out.ficha.push({
    id_ficha: idFicha,
    codigo_ficha: codigoFicha,
    estado_ficha: "Activa",
    fecha_inicio: null,
    fecha_fin: null,
    codigo_programa: codigoPrograma,
  });

  const estadoSet = new Map();
  const juicioSet = new Map();
  const funcSet = new Map();
  const compSet = new Map();
  const resSet = new Map();
  const aprendizSet = new Map();
  const matriculaSet = new Map();

  const dataRows = matrix.slice(headerIdx + 1);

  // Carry-forward: en reportes SENA, las columnas del aprendiz (tipo, documento,
  // nombre, apellidos, estado) solo se llenan en la primera fila de cada bloque.
  // Las filas siguientes las dejan vacías. Propagamos el último valor conocido.
  let lastTipo = null;
  let lastDoc = null;
  let lastNombre = null;
  let lastApellido = null;
  let lastEstado = null;

  for (const row of dataRows) {
    let rawTipo = idxTipo >= 0 ? row[idxTipo] : null;
    let rawDoc = row[idxDoc];
    let rawNombre = row[idxNombre];
    let rawApellido = row[idxApellidos];
    let rawEstado = row[idxEstado];
    const rawComp = row[idxCompetencia];
    const rawRes = row[idxResultado];
    const rawJuicio = row[idxJuicio];
    const rawFecha = row[idxFecha];
    const rawFunc = row[idxFuncionario];

    // Si la fila tiene documento, actualizamos el carry-forward
    const docStr = String(rawDoc ?? "").trim();
    const nombreStr = String(rawNombre ?? "").trim();
    const apellidoStr = String(rawApellido ?? "").trim();

    if (docStr) {
      // Nueva sección de aprendiz
      lastTipo = rawTipo;
      lastDoc = rawDoc;
      lastNombre = rawNombre;
      lastApellido = rawApellido;
      lastEstado = rawEstado;
    } else {
      // Fila sin documento: propagar del aprendiz anterior
      rawTipo = lastTipo;
      rawDoc = lastDoc;
      rawNombre = lastNombre;
      rawApellido = lastApellido;
      if (!String(rawEstado ?? "").trim()) rawEstado = lastEstado;
    }

    const documento = String(rawDoc ?? "").trim();
    const nombres = String(rawNombre ?? "").trim();
    const apellidos = String(rawApellido ?? "").trim();
    if (!documento || (!nombres && !apellidos)) continue;

    const estadoTxt = String(rawEstado ?? "Por evaluar").trim() || "Por evaluar";
    const estadoCode = safeToken(estadoTxt).slice(0, 10);
    if (!estadoSet.has(estadoCode)) {
      estadoSet.set(estadoCode, { descripcion: estadoTxt, codigo: estadoCode });
    }

    const juicioTxt = String(rawJuicio ?? "Por evaluar").trim() || "Por evaluar";
    let juicioCode = safeToken(juicioTxt).slice(0, 10);
    
    // Mapeo inteligente a códigos estándar
    const upperJuicio = juicioTxt.toUpperCase();
    if (upperJuicio.includes("APROBADO") && !upperJuicio.includes("NO")) juicioCode = "AP";
    else if (upperJuicio.includes("NO APROBADO") || upperJuicio.includes("REPROBADO")) juicioCode = "NA";
    else if (upperJuicio.includes("POR EVALUAR") || upperJuicio.includes("PENDIENTE")) juicioCode = "PE";

    if (!juicioSet.has(juicioCode)) {
      juicioSet.set(juicioCode, { nombre: juicioTxt, codigo: juicioCode });
    }

    const funcName = String(rawFunc ?? "Sin funcionario").trim() || "Sin funcionario";
    if (!funcSet.has(funcName)) {
      const parts = funcName.split(/\s+/).filter(Boolean);
      const nombresFunc = parts.slice(0, 2).join(" ") || funcName;
      const apellidosFunc = parts.slice(2).join(" ") || "";
      funcSet.set(funcName, {
        tipo_documento: "CC",
        numero_documento: `IMP-${hashId(funcName).toString(16).slice(0, 10).toUpperCase()}`,
        nombres: nombresFunc,
        apellidos: apellidosFunc,
        cargo: "Instructor",
        estado: "Activo",
      });
    }

    const compTxt = String(rawComp ?? "Competencia no definida").trim() || "Competencia no definida";
    const compCode = `COMP-${safeToken(compTxt).slice(0, 20)}`;
    if (!compSet.has(compCode)) {
      compSet.set(compCode, {
        codigo_competencia: compCode,
        nombre_competencia: compTxt,
        descripcion: compTxt,
        codigo_programa: codigoPrograma,
      });
    }

    const resTxt = String(rawRes ?? "Resultado no definido").trim() || "Resultado no definido";
    const resCode = `RA-${safeToken(resTxt).slice(0, 24)}`;
    if (!resSet.has(resCode)) {
      resSet.set(resCode, {
        codigo_resultado: resCode,
        descripcion: resTxt,
        codigo_competencia: compCode,
      });
    }

    if (!aprendizSet.has(documento)) {
      aprendizSet.set(documento, {
        documento,
        tipo_documento: String(rawTipo ?? "CC").trim() || "CC",
        nombres,
        apellidos,
      });
    }

    const matriculaKey = `${documento}::${codigoFicha}`;
    if (!matriculaSet.has(matriculaKey)) {
      matriculaSet.set(matriculaKey, {
        id_aprendiz: documento,
        codigo_ficha: codigoFicha,
        codigo_estado: estadoCode,
      });
    }

    out.juicios_evaluativos.push({
      documento,
      codigo_ficha: codigoFicha,
      codigo_resultado: resCode,
      codigo_juicio: juicioCode,
      numero_documento: funcSet.get(funcName).numero_documento,
      fecha: rawFecha ? String(rawFecha).trim() : null,
      observaciones: null,
    });
  }

  out.estado_aprendiz = Array.from(estadoSet.values());
  out.tipo_juicio = Array.from(juicioSet.values());
  out.funcionario = Array.from(funcSet.values());
  out.competencia = Array.from(compSet.values());
  out.resultado_aprendizaje = Array.from(resSet.values());
  out.aprendiz = Array.from(aprendizSet.values());
  out.matricula = Array.from(matriculaSet.values());

  console.log(`[PARSER] Aprendices detectados: ${out.aprendiz.length}`);
  console.log(`[PARSER] Documentos únicos:`, out.aprendiz.map(a => `${a.tipo_documento}:${a.documento} - ${a.nombres} ${a.apellidos}`));
  console.log(`[PARSER] Ficha: ${codigoFicha} | id_ficha: ${idFicha} | Programa: ${codigoPrograma}`);

  return {
    rowsByTable: out,
    detectedHeaderRow: headerIdx + 1,
    inferredFromSheet: sheetName,
  };
}

// ==========================
// Diagnóstico: Vista previa del Excel sin insertar
// ==========================
app.post("/api/import/preview", upload.single("file"), (req, res) => {
  if (!req.file?.buffer) {
    return res.status(400).json({ ok: false, message: "Falta archivo" });
  }
  let workbook;
  try {
    workbook = xlsx.read(req.file.buffer, { type: "buffer" });
  } catch (e) {
    return res.status(400).json({ ok: false, message: "Archivo inválido", detail: e.message });
  }

  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const matrix = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: null });

  const normalizedRows = matrix.map((row) => row.map((c) => normalizeKey(c)));
  const hasAny = (row, patterns) =>
    row.some((cell) => patterns.some((p) => String(cell || "").includes(p)));

  const headerIdx = normalizedRows.findIndex((row) => {
    const rowText = row.filter(Boolean).join(" ");
    const score =
      (hasAny(row, ["tipo"]) ? 1 : 0) +
      (hasAny(row, ["numero_de_identificacion", "numero_identificacion", "documento", "identificacion"]) ? 1 : 0) +
      (hasAny(row, ["nombre", "nombres"]) ? 1 : 0) +
      (hasAny(row, ["apellidos", "apellido"]) ? 1 : 0) +
      (hasAny(row, ["competencia"]) ? 1 : 0) +
      (hasAny(row, ["resultado_de_aprendizaje", "resultado"]) ? 1 : 0) +
      (hasAny(row, ["juicio"]) ? 1 : 0);
    return score >= 5 || (rowText.includes("competencia") && rowText.includes("resultado"));
  });

  if (headerIdx === -1) {
    return res.json({
      ok: false,
      message: "No se encontró fila de encabezado",
      first20Rows: matrix.slice(0, 20).map((row, i) => ({ rowIndex: i, normalized: normalizedRows[i], raw: row })),
    });
  }

  const header = normalizedRows[headerIdx];
  const headerRaw = matrix[headerIdx];
  const indexOf = (...candidates) =>
    header.findIndex((h) => candidates.some((c) => h === c || h.includes(c)));

  const idxTipo = indexOf("tipo");
  const idxDoc = indexOf("numero_de_identificacion", "numero_identificacion", "documento", "identificacion");
  const idxNombre = indexOf("nombre", "nombres");
  const idxApellidos = indexOf("apellidos", "apellido");
  const idxEstado = indexOf("estado");
  const idxCompetencia = indexOf("competencia");
  const idxResultado = indexOf("resultado_de_aprendizaje", "resultado");
  const idxJuicio = indexOf("juicio", "juicio_de");

  const dataRows = matrix.slice(headerIdx + 1);
  const uniqueDocs = new Set();
  const sampleRows = [];
  for (let i = 0; i < dataRows.length; i++) {
    const row = dataRows[i];
    const doc = String(row[idxDoc] ?? "").trim();
    if (doc) uniqueDocs.add(doc);
    if (i < 10 || (doc && uniqueDocs.size <= 5)) {
      sampleRows.push({
        dataRowIndex: i,
        excelRow: headerIdx + 2 + i,
        tipo: row[idxTipo],
        documento: row[idxDoc],
        nombre: row[idxNombre],
        apellidos: row[idxApellidos],
        estado: row[idxEstado],
        competencia: row[idxCompetencia] ? String(row[idxCompetencia]).substring(0, 50) : null,
        resultado: row[idxResultado] ? String(row[idxResultado]).substring(0, 50) : null,
        juicio: row[idxJuicio],
        allCells: row,
      });
    }
  }

  // Meta (filas antes del header)
  const meta = {};
  for (let i = 0; i < headerIdx; i++) {
    const row = matrix[i] || [];
    meta[`row_${i}`] = { raw: row, normalized: normalizedRows[i] };
  }

  return res.json({
    ok: true,
    sheetName,
    totalMatrixRows: matrix.length,
    headerIdx_0based: headerIdx,
    headerIdx_1based: headerIdx + 1,
    headerNormalized: header,
    headerRaw,
    columnIndices: {
      tipo: idxTipo,
      documento: idxDoc,
      nombre: idxNombre,
      apellidos: idxApellidos,
      estado: idxEstado,
      competencia: idxCompetencia,
      resultado: idxResultado,
      juicio: idxJuicio,
    },
    dataRowsCount: dataRows.length,
    uniqueDocumentosFound: uniqueDocs.size,
    uniqueDocumentos: Array.from(uniqueDocs),
    sampleDataRows: sampleRows,
    metaRows: meta,
  });
});

function buildFunctionRoute(path, fnName, paramDefs) {
  app.get(path, async (req, res) => {
    try {
      const values = paramDefs.map((def) => def.parser(req.query[def.key]));
      const placeholders = values.map((_, i) => `$${i + 1}`).join(", ");
      const sql = `SELECT * FROM ${fnName}(${placeholders});`;
      const { rows } = await pool.query(sql, values);
      res.json({ ok: true, count: rows.length, data: rows });
    } catch (error) {
      console.error(`Error en ${path}:`, error);
      res.status(500).json({
        ok: false,
        message: `Error ejecutando ${fnName}`,
        detail: error.message,
      });
    }
  });
}

app.get("/api/dashboard/resumen-general", async (_req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM v_resumen_general;");
    res.json({ ok: true, data: rows[0] || null });
  } catch (error) {
    console.error("Error en /api/dashboard/resumen-general:", error);
    res.status(500).json({
      ok: false,
      message: "Error consultando v_resumen_general",
      detail: error.message,
    });
  }
});

// ==========================
// Importación masiva desde Excel (.xlsx)
// ==========================
// Convención recomendada:
// - El Excel debe tener hojas con estos nombres (pueden omitirse si no aplica):
//   estado_aprendiz, tipo_juicio, funcionario, programa, ficha, aprendiz, matricula,
//   competencia, resultado_aprendizaje, juicios_evaluativos
//
// - Encabezados: se normalizan (minúsculas, sin tildes, espacios -> "_").
//   Ej: "Código Programa" -> "codigo_programa"
//
// Endpoint:
//   POST /api/import/excel   (multipart/form-data, campo archivo: "file")
app.post("/api/import/excel", upload.single("file"), async (req, res) => {
  if (!req.file?.buffer) {
    return res.status(400).json({ ok: false, message: "Falta el archivo .xlsx (campo: file)" });
  }

  let workbook;
  try {
    workbook = xlsx.read(req.file.buffer, { type: "buffer" });
  } catch (e) {
    return res.status(400).json({ ok: false, message: "Archivo Excel inválido", detail: e.message });
  }

  const sheetMap = getWorkbookSheetMap(workbook);
  const resolved = {
    estado_aprendiz: sheetToRowsByAliases(workbook, sheetMap, ["estado_aprendiz", "estado aprendiz", "estados_aprendiz", "estados aprendiz", "estados"]),
    tipo_juicio: sheetToRowsByAliases(workbook, sheetMap, ["tipo_juicio", "tipo juicio", "tipos_juicio", "tipos juicio"]),
    funcionario: sheetToRowsByAliases(workbook, sheetMap, ["funcionario", "funcionarios"]),
    programa: sheetToRowsByAliases(workbook, sheetMap, ["programa", "programas"]),
    ficha: sheetToRowsByAliases(workbook, sheetMap, ["ficha", "fichas"]),
    aprendiz: sheetToRowsByAliases(workbook, sheetMap, ["aprendiz", "aprendices"]),
    matricula: sheetToRowsByAliases(workbook, sheetMap, ["matricula", "matriculas", "matrícula", "matrículas"]),
    competencia: sheetToRowsByAliases(workbook, sheetMap, ["competencia", "competencias"]),
    resultado_aprendizaje: sheetToRowsByAliases(workbook, sheetMap, ["resultado_aprendizaje", "resultado aprendizaje", "resultados_aprendizaje", "resultados aprendizaje", "resultado", "resultados"]),
    juicios_evaluativos: sheetToRowsByAliases(workbook, sheetMap, ["juicios_evaluativos", "juicios evaluativos", "juicios", "juicio"]),
  };

  const rows = Object.fromEntries(
    Object.entries(resolved).map(([k, v]) => [k, v.rows])
  );
  let summarySingleSheet = null;

  // Modo hoja única:
  // Si no se detectó ninguna hoja por nombre, permite usar una sola hoja (ej. "Hoja")
  // con una columna "tabla" para enrutar cada fila.
  const hasAnyMatchedSheet = Object.values(resolved).some((v) => !!v.sheetName);
  if (!hasAnyMatchedSheet && (workbook.SheetNames || []).length === 1) {
    const singleSheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[singleSheetName];
    const singleRawRows = xlsx.utils.sheet_to_json(sheet, { defval: null }).map(normalizeRowKeys);
    const singleSheetColumns = singleRawRows.length ? Object.keys(singleRawRows[0]) : [];

    for (const r of singleRawRows) {
      const tableName = normalizeTableName(r.tabla || r.sheet || r.hoja || r.table);
      if (!tableName) continue;
      rows[tableName].push(r);
    }

    // Modo reporte (como la imagen: encabezado + grilla de juicios)
    const noRowsAssigned = Object.values(rows).every((arr) => arr.length === 0);
    if (noRowsAssigned) {
      const parsed = parseEvaluationReportSheet(workbook, singleSheetName);
      if (parsed) {
        for (const k of Object.keys(rows)) rows[k].push(...(parsed.rowsByTable[k] || []));
        summarySingleSheet = {
          name: singleSheetName,
          mode: "reporte_juicios",
          detectedHeaderRow: parsed.detectedHeaderRow,
          totalRows: singleRawRows.length,
          detectedColumns: singleSheetColumns,
          hint: "Se detectó formato de reporte. Se infirieron programa/ficha/competencias/resultados para permitir importación normalizada.",
        };
      }
    }

    for (const key of Object.keys(resolved)) {
      if (!rows[key].length) {
        resolved[key].sheetName = null;
      } else if (summarySingleSheet && summarySingleSheet.mode === "reporte_juicios") {
        resolved[key].sheetName = singleSheetName + " (detectado como reporte)";
      } else {
        resolved[key].sheetName = singleSheetName + " (por columna tabla)";
      }
    }

    if (!summarySingleSheet) {
      summarySingleSheet = {
        name: singleSheetName,
        mode: "hoja_unica_sin_ruteo",
        totalRows: singleRawRows.length,
        detectedColumns: singleSheetColumns,
        hint:
          "Para modo hoja unica, agrega columna 'tabla' con valores como programa, ficha, aprendiz, matricula, competencia, resultado_aprendizaje, juicios_evaluativos, funcionario, estado_aprendiz o tipo_juicio.",
      };
    }
  }

  const meaningfulSignals = countMeaningfulImportSignals(rows);
  const totalImportRows = Object.values(rows).reduce((sum, list) => sum + list.length, 0);
  if (totalImportRows === 0 || meaningfulSignals < 2) {
    return res.status(400).json({
      ok: false,
      message: "El archivo no parece corresponder a juicios evaluativos.",
      detail: "No se encontraron hojas reconocidas ni columnas minimas como documento, aprendiz, ficha, competencia, resultado o juicio. Verifique que sea el consolidado correcto de Sofia Plus o una plantilla del sistema.",
      workbookSheets: workbook.SheetNames || [],
      detectedRows: Object.fromEntries(Object.entries(rows).map(([k, v]) => [k, v.length])),
      singleSheet: summarySingleSheet || null,
    });
  }

  const summary = {
    ok: true,
    workbookSheets: workbook.SheetNames || [],
    matchedSheets: Object.fromEntries(
      Object.entries(resolved).map(([k, v]) => [k, v.sheetName])
    ),
    sheets: Object.fromEntries(Object.entries(rows).map(([k, v]) => [k, v.length])),
    inserted: {},
    skipped: {},
    errors: [],
    singleSheet: summarySingleSheet || null,
  };

  let client;
  try {
    client = await pool.connect();
    await client.query("BEGIN");

    const countInsert = (table, n) => (summary.inserted[table] = (summary.inserted[table] || 0) + n);
    const countSkip = (table, n) => (summary.skipped[table] = (summary.skipped[table] || 0) + n);
    const addError = (table, rowIndex, message, row) => {
      summary.errors.push({ table, rowIndex, message, row });
    };

    // 1) Catálogos base
    if (rows.estado_aprendiz.length) {
      let ok = 0;
      for (let i = 0; i < rows.estado_aprendiz.length; i++) {
        const r = rows.estado_aprendiz[i];
        const descripcion = toStringOrNull(r.descripcion);
        const codigo = toStringOrNull(r.codigo);
        if (!descripcion) {
          addError("estado_aprendiz", i + 2, "descripcion es requerida", r);
          continue;
        }
        await client.query(
          `INSERT INTO estado_aprendiz (descripcion, codigo)
           VALUES ($1, $2)
           ON CONFLICT (codigo) DO UPDATE SET descripcion = EXCLUDED.descripcion`,
          [descripcion, codigo]
        );
        ok++;
      }
      countInsert("estado_aprendiz", ok);
    }

    if (rows.tipo_juicio.length) {
      let ok = 0;
      for (let i = 0; i < rows.tipo_juicio.length; i++) {
        const r = rows.tipo_juicio[i];
        const nombre = toStringOrNull(r.nombre);
        const codigo = toStringOrNull(r.codigo);
        if (!nombre) {
          addError("tipo_juicio", i + 2, "nombre es requerido", r);
          continue;
        }
        await client.query(
          `INSERT INTO tipo_juicio (nombre, codigo)
           VALUES ($1, $2)
           ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre`,
          [nombre, codigo]
        );
        ok++;
      }
      countInsert("tipo_juicio", ok);
    }

    // 2) Funcionario
    if (rows.funcionario.length) {
      let ok = 0;
      for (let i = 0; i < rows.funcionario.length; i++) {
        const r = rows.funcionario[i];
        const numero_documento = toStringOrNull(r.numero_documento);
        if (!numero_documento) {
          addError("funcionario", i + 2, "numero_documento es requerido", r);
          continue;
        }
        await client.query(
          `INSERT INTO funcionario
           (tipo_documento, numero_documento, nombres, apellidos, cargo, email, estado)
           VALUES ($1,$2,$3,$4,$5,$6,$7)
           ON CONFLICT (numero_documento) DO UPDATE SET
             tipo_documento = EXCLUDED.tipo_documento,
             nombres = EXCLUDED.nombres,
             apellidos = EXCLUDED.apellidos,
             cargo = EXCLUDED.cargo,
             email = EXCLUDED.email,
             estado = EXCLUDED.estado`,
          [
            toStringOrNull(r.tipo_documento),
            numero_documento,
            toStringOrNull(r.nombres),
            toStringOrNull(r.apellidos),
            toStringOrNull(r.cargo),
            toStringOrNull(r.email),
            toStringOrNull(r.estado) || "Activo",
          ]
        );
        ok++;
      }
      countInsert("funcionario", ok);
    }

    // 3) Programa
    if (rows.programa.length) {
      let ok = 0;
      for (let i = 0; i < rows.programa.length; i++) {
        const r = rows.programa[i];
        const codigo_programa = toStringOrNull(r.codigo_programa);
        if (!codigo_programa) {
          addError("programa", i + 2, "codigo_programa es requerido", r);
          continue;
        }
        await client.query(
          `INSERT INTO programa
           (codigo_programa, denominacion, version, nivel_formacion, duracion_horas, estado)
           VALUES ($1,$2,$3,$4,$5,$6)
           ON CONFLICT (codigo_programa) DO UPDATE SET
             denominacion = EXCLUDED.denominacion,
             version = EXCLUDED.version,
             nivel_formacion = EXCLUDED.nivel_formacion,
             duracion_horas = EXCLUDED.duracion_horas,
             estado = EXCLUDED.estado`,
          [
            codigo_programa,
            toStringOrNull(r.denominacion),
            toIntOrNull(r.version),
            toStringOrNull(r.nivel_formacion),
            toIntOrNull(r.duracion_horas),
            toStringOrNull(r.estado) || "Activo",
          ]
        );
        ok++;
      }
      countInsert("programa", ok);
    }

    // Helpers de lookup (después de upserts)
    const mapRows = async (sql, keyCol, valCol) => {
      const { rows } = await client.query(sql);
      const m = new Map();
      for (const r of rows) m.set(String(r[keyCol]), r[valCol]);
      return m;
    };

    const programaIdByCodigo = await mapRows(
      "SELECT id, codigo_programa FROM programa",
      "codigo_programa",
      "id"
    );

    // 4) Ficha
    if (rows.ficha.length) {
      let ok = 0;
      for (let i = 0; i < rows.ficha.length; i++) {
        const r = rows.ficha[i];
        const id_ficha = toIntOrNull(r.id_ficha);
        const codigo_ficha = toStringOrNull(r.codigo_ficha);
        const id_programa =
          toIntOrNull(r.id_programa) ||
          (toStringOrNull(r.codigo_programa) ? programaIdByCodigo.get(String(r.codigo_programa)) : null);

        if (!id_ficha) {
          addError("ficha", i + 2, "id_ficha es requerido (PK)", r);
          continue;
        }
        if (!id_programa) {
          addError("ficha", i + 2, "id_programa o codigo_programa es requerido", r);
          continue;
        }

        await client.query(
          `INSERT INTO ficha
           (id_ficha, codigo_ficha, estado_ficha, fecha_inicio, fecha_fin, id_programa)
           VALUES ($1,$2,$3,$4,$5,$6)
           ON CONFLICT (id_ficha) DO UPDATE SET
             codigo_ficha = EXCLUDED.codigo_ficha,
             estado_ficha = EXCLUDED.estado_ficha,
             fecha_inicio = EXCLUDED.fecha_inicio,
             fecha_fin = EXCLUDED.fecha_fin,
             id_programa = EXCLUDED.id_programa`,
          [
            id_ficha,
            codigo_ficha,
            toStringOrNull(r.estado_ficha),
            toPgDateOrTimestamp(r.fecha_inicio, "date"),
            toPgDateOrTimestamp(r.fecha_fin, "date"),
            id_programa,
          ]
        );
        ok++;
      }
      countInsert("ficha", ok);
    }

    // 5) Aprendiz
    if (rows.aprendiz.length) {
      let ok = 0;
      for (let i = 0; i < rows.aprendiz.length; i++) {
        const r = rows.aprendiz[i];
        const documento = toStringOrNull(r.documento);
        if (!documento) {
          addError("aprendiz", i + 2, "documento es requerido (PK)", r);
          continue;
        }
        await client.query(
          `INSERT INTO aprendiz
           (documento, tipo_documento, nombres, apellidos, email, telefono, fecha_nacimiento, genero)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           ON CONFLICT (documento) DO UPDATE SET
             tipo_documento = EXCLUDED.tipo_documento,
             nombres = EXCLUDED.nombres,
             apellidos = EXCLUDED.apellidos,
             email = EXCLUDED.email,
             telefono = EXCLUDED.telefono,
             fecha_nacimiento = EXCLUDED.fecha_nacimiento,
             genero = EXCLUDED.genero`,
          [
            documento,
            toStringOrNull(r.tipo_documento),
            toStringOrNull(r.nombres),
            toStringOrNull(r.apellidos),
            toStringOrNull(r.email),
            toStringOrNull(r.telefono),
            toPgDateOrTimestamp(r.fecha_nacimiento, "date"),
            toStringOrNull(r.genero),
          ]
        );
        ok++;
      }
      countInsert("aprendiz", ok);
    }

    const estadoIdByCodigo = await mapRows(
      "SELECT id_estado, codigo FROM estado_aprendiz",
      "codigo",
      "id_estado"
    );

    const fichaIdByCodigo = await mapRows(
      "SELECT id_ficha, codigo_ficha FROM ficha WHERE codigo_ficha IS NOT NULL",
      "codigo_ficha",
      "id_ficha"
    );

    // 6) Matrícula
    if (rows.matricula.length) {
      let ok = 0;
      for (let i = 0; i < rows.matricula.length; i++) {
        const r = rows.matricula[i];
        const id_aprendiz = toStringOrNull(r.id_aprendiz) || toStringOrNull(r.documento);
        const id_ficha =
          toIntOrNull(r.id_ficha) ||
          (toStringOrNull(r.codigo_ficha) ? fichaIdByCodigo.get(String(r.codigo_ficha)) : null);
        const id_estado =
          toIntOrNull(r.id_estado) ||
          (toStringOrNull(r.codigo_estado) ? estadoIdByCodigo.get(String(r.codigo_estado)) : null);

        if (!id_aprendiz) {
          addError("matricula", i + 2, "id_aprendiz (documento) es requerido", r);
          continue;
        }
        if (!id_ficha) {
          addError("matricula", i + 2, "id_ficha o codigo_ficha es requerido", r);
          continue;
        }
        if (!id_estado) {
          addError("matricula", i + 2, "id_estado o codigo_estado es requerido", r);
          continue;
        }

        await client.query(
          `INSERT INTO matricula
           (fecha_ingreso, fecha_retiro, id_aprendiz, id_ficha, id_estado)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (id_aprendiz, id_ficha) DO UPDATE SET
             fecha_ingreso = EXCLUDED.fecha_ingreso,
             fecha_retiro = EXCLUDED.fecha_retiro,
             id_estado = EXCLUDED.id_estado`,
          [
            toPgDateOrTimestamp(r.fecha_ingreso, "date"),
            toPgDateOrTimestamp(r.fecha_retiro, "date"),
            id_aprendiz,
            id_ficha,
            id_estado,
          ]
        );
        ok++;
      }
      countInsert("matricula", ok);
    }

    // 7) Competencia
    if (rows.competencia.length) {
      let ok = 0;
      for (let i = 0; i < rows.competencia.length; i++) {
        const r = rows.competencia[i];
        const codigo_competencia = toStringOrNull(r.codigo_competencia);
        const id_programa =
          toIntOrNull(r.id_programa) ||
          (toStringOrNull(r.codigo_programa) ? programaIdByCodigo.get(String(r.codigo_programa)) : null);

        if (!codigo_competencia) {
          addError("competencia", i + 2, "codigo_competencia es requerido", r);
          continue;
        }
        if (!id_programa) {
          addError("competencia", i + 2, "id_programa o codigo_programa es requerido", r);
          continue;
        }

        await client.query(
          `INSERT INTO competencia
           (codigo_competencia, nombre_competencia, descripcion, id_programa, duracion_horas)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (codigo_competencia) DO UPDATE SET
             nombre_competencia = EXCLUDED.nombre_competencia,
             descripcion = EXCLUDED.descripcion,
             id_programa = EXCLUDED.id_programa,
             duracion_horas = EXCLUDED.duracion_horas`,
          [
            codigo_competencia,
            toStringOrNull(r.nombre_competencia),
            toStringOrNull(r.descripcion),
            id_programa,
            toIntOrNull(r.duracion_horas),
          ]
        );
        ok++;
      }
      countInsert("competencia", ok);
    }

    const competenciaIdByCodigo = await mapRows(
      "SELECT id_competencia, codigo_competencia FROM competencia",
      "codigo_competencia",
      "id_competencia"
    );

    // 8) Resultado de aprendizaje
    if (rows.resultado_aprendizaje.length) {
      let ok = 0;
      for (let i = 0; i < rows.resultado_aprendizaje.length; i++) {
        const r = rows.resultado_aprendizaje[i];
        const codigo_resultado = toStringOrNull(r.codigo_resultado);
        const id_competencia =
          toIntOrNull(r.id_competencia) ||
          (toStringOrNull(r.codigo_competencia)
            ? competenciaIdByCodigo.get(String(r.codigo_competencia))
            : null);

        if (!codigo_resultado) {
          addError("resultado_aprendizaje", i + 2, "codigo_resultado es requerido", r);
          continue;
        }
        if (!id_competencia) {
          addError("resultado_aprendizaje", i + 2, "id_competencia o codigo_competencia es requerido", r);
          continue;
        }

        await client.query(
          `INSERT INTO resultado_aprendizaje
           (codigo_resultado, descripcion, id_competencia, duracion_horas)
           VALUES ($1,$2,$3,$4)
           ON CONFLICT (codigo_resultado) DO UPDATE SET
             descripcion = EXCLUDED.descripcion,
             id_competencia = EXCLUDED.id_competencia,
             duracion_horas = EXCLUDED.duracion_horas`,
          [
            codigo_resultado,
            toStringOrNull(r.descripcion),
            id_competencia,
            toIntOrNull(r.duracion_horas),
          ]
        );
        ok++;
      }
      countInsert("resultado_aprendizaje", ok);
    }

    const resultadoIdByCodigo = await mapRows(
      "SELECT id_resultado, codigo_resultado FROM resultado_aprendizaje",
      "codigo_resultado",
      "id_resultado"
    );

    const tipoJuicioIdByCodigo = await mapRows(
      "SELECT id, codigo FROM tipo_juicio WHERE codigo IS NOT NULL",
      "codigo",
      "id"
    );

    const funcionarioIdByNumeroDoc = await mapRows(
      "SELECT id_funcionario, numero_documento FROM funcionario WHERE numero_documento IS NOT NULL",
      "numero_documento",
      "id_funcionario"
    );

    const matriculaIdByKey = async (docAprendiz, idFicha) => {
      const { rows } = await client.query(
        "SELECT id_matricula FROM matricula WHERE id_aprendiz = $1 AND id_ficha = $2 LIMIT 1",
        [docAprendiz, idFicha]
      );
      return rows[0]?.id_matricula ?? null;
    };

    // 9) Juicios evaluativos
    if (rows.juicios_evaluativos.length) {
      let ok = 0;
      for (let i = 0; i < rows.juicios_evaluativos.length; i++) {
        const r = rows.juicios_evaluativos[i];

        const id_resultado =
          toIntOrNull(r.id_resultado) ||
          (toStringOrNull(r.codigo_resultado) ? resultadoIdByCodigo.get(String(r.codigo_resultado)) : null);

        const id_tipo =
          toIntOrNull(r.id_tipo) ||
          (toStringOrNull(r.codigo_juicio) ? tipoJuicioIdByCodigo.get(String(r.codigo_juicio)) : null);

        const id_funcionario =
          toIntOrNull(r.id_funcionario) ||
          (toStringOrNull(r.numero_documento)
            ? funcionarioIdByNumeroDoc.get(String(r.numero_documento))
            : null);

        let id_matricula = toIntOrNull(r.id_matricula);
        if (!id_matricula) {
          const doc = toStringOrNull(r.documento) || toStringOrNull(r.doc_aprendiz) || toStringOrNull(r.id_aprendiz);
          const idFicha =
            toIntOrNull(r.id_ficha) ||
            (toStringOrNull(r.codigo_ficha) ? fichaIdByCodigo.get(String(r.codigo_ficha)) : null);
          if (doc && idFicha) id_matricula = await matriculaIdByKey(doc, idFicha);
        }

        if (!id_matricula) {
          addError("juicios_evaluativos", i + 2, "id_matricula o (documento + id_ficha/codigo_ficha) es requerido", r);
          continue;
        }
        if (!id_resultado) {
          addError("juicios_evaluativos", i + 2, "id_resultado o codigo_resultado es requerido", r);
          continue;
        }
        if (!id_tipo) {
          addError("juicios_evaluativos", i + 2, "id_tipo o codigo_juicio es requerido", r);
          continue;
        }

        await client.query(
          `INSERT INTO juicios_evaluativos
           (fecha, observaciones, id_matricula, id_resultado, id_tipo, id_funcionario)
           VALUES ($1,$2,$3,$4,$5,$6)
           ON CONFLICT (id_matricula, id_resultado) DO UPDATE SET
             fecha = COALESCE(EXCLUDED.fecha, juicios_evaluativos.fecha),
             observaciones = EXCLUDED.observaciones,
             id_tipo = EXCLUDED.id_tipo,
             id_funcionario = EXCLUDED.id_funcionario`,
          [
            toPgDateOrTimestamp(r.fecha, "timestamp"),
            toStringOrNull(r.observaciones),
            id_matricula,
            id_resultado,
            id_tipo,
            id_funcionario,
          ]
        );
        ok++;
      }
      countInsert("juicios_evaluativos", ok);
    }

    await client.query("COMMIT");
    return res.json(summary);
  } catch (error) {
    if (client) {
      try {
        await client.query("ROLLBACK");
      } catch (_rollbackError) {
        // Ignorado: si falla conexión no habrá transacción activa.
      }
    }
    console.error("Error importando Excel:", error);
    return res.status(500).json({
      ok: false,
      message: "Error importando Excel",
      detail: error.message,
      partial: summary,
    });
  } finally {
    if (client) client.release();
  }
});

buildFunctionRoute("/api/fn_total_aprendices", "fn_total_aprendices", [
  { key: "p_id_ficha", parser: toIntOrNull },
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_version", parser: toIntOrNull },
  { key: "p_nivel_formacion", parser: toStringOrNull },
  { key: "p_estado_ficha", parser: toStringOrNull },
]);

buildFunctionRoute("/api/fn_aprendices_por_estado", "fn_aprendices_por_estado", [
  { key: "p_id_estado", parser: toIntOrNull },
  { key: "p_codigo_estado", parser: toStringOrNull },
]);

buildFunctionRoute(
  "/api/fn_resultados_por_aprendiz",
  "fn_resultados_por_aprendiz",
  [
    { key: "p_documento", parser: toStringOrNull },
    { key: "p_tipo_documento", parser: toStringOrNull },
    { key: "p_id_ficha", parser: toIntOrNull },
    { key: "p_id_programa", parser: toIntOrNull },
    { key: "p_nombre_aprendiz", parser: toStringOrNull },
  ]
);

buildFunctionRoute("/api/fn_resultados_aprobados", "fn_resultados_aprobados", [
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_id_competencia", parser: toIntOrNull },
  { key: "p_id_resultado", parser: toIntOrNull },
  { key: "p_fecha_desde", parser: toStringOrNull },
  { key: "p_fecha_hasta", parser: toStringOrNull },
]);

buildFunctionRoute("/api/fn_resultados_pendientes", "fn_resultados_pendientes", [
  { key: "p_documento", parser: toStringOrNull },
  { key: "p_id_ficha", parser: toIntOrNull },
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_id_competencia", parser: toIntOrNull },
]);

buildFunctionRoute("/api/fn_avance_aprendiz", "fn_avance_aprendiz", [
  { key: "p_documento", parser: toStringOrNull },
  { key: "p_id_ficha", parser: toIntOrNull },
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_min_avance", parser: toNumOrNull },
  { key: "p_max_avance", parser: toNumOrNull },
]);

buildFunctionRoute(
  "/api/fn_competencias_aprobacion",
  "fn_competencias_aprobacion",
  [
    { key: "p_id_programa", parser: toIntOrNull },
    { key: "p_id_competencia", parser: toIntOrNull },
    { key: "p_min_aprobacion", parser: toNumOrNull },
  ]
);

buildFunctionRoute("/api/fn_juicios_por_funcionario", "fn_juicios_por_funcionario", [
  { key: "p_id_funcionario", parser: toIntOrNull },
  { key: "p_nombre_funcionario", parser: toStringOrNull },
  { key: "p_cargo", parser: toStringOrNull },
  { key: "p_fecha_desde", parser: toStringOrNull },
  { key: "p_fecha_hasta", parser: toStringOrNull },
]);

buildFunctionRoute("/api/fn_resumen_funcionario", "fn_resumen_funcionario", [
  { key: "p_id_funcionario", parser: toIntOrNull },
  { key: "p_cargo", parser: toStringOrNull },
]);

buildFunctionRoute("/api/fn_juicios_por_fecha", "fn_juicios_por_fecha", [
  { key: "p_fecha_exacta", parser: toStringOrNull },
  { key: "p_fecha_desde", parser: toStringOrNull },
  { key: "p_fecha_hasta", parser: toStringOrNull },
  { key: "p_hora_desde", parser: toStringOrNull },
  { key: "p_hora_hasta", parser: toStringOrNull },
  { key: "p_año", parser: toIntOrNull },
  { key: "p_mes", parser: toIntOrNull },
  { key: "p_semana", parser: toIntOrNull },
]);

buildFunctionRoute("/api/fn_aprendices_pendientes", "fn_aprendices_pendientes", [
  { key: "p_documento", parser: toStringOrNull },
  { key: "p_id_ficha", parser: toIntOrNull },
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_id_estado", parser: toIntOrNull },
  { key: "p_nombre_aprendiz", parser: toStringOrNull },
  { key: "p_min_pendientes", parser: toIntOrNull },
]);

buildFunctionRoute(
  "/api/fn_dashboard_aprendices_formacion",
  "fn_dashboard_aprendices_formacion",
  [
    { key: "p_id_programa", parser: toIntOrNull },
    { key: "p_nivel_formacion", parser: toStringOrNull },
    { key: "p_estado_programa", parser: toStringOrNull },
  ]
);

buildFunctionRoute(
  "/api/fn_dashboard_aprobados_vs_pendientes",
  "fn_dashboard_aprobados_vs_pendientes",
  [
    { key: "p_id_programa", parser: toIntOrNull },
    { key: "p_id_ficha", parser: toIntOrNull },
    { key: "p_fecha_desde", parser: toStringOrNull },
    { key: "p_fecha_hasta", parser: toStringOrNull },
  ]
);

buildFunctionRoute(
  "/api/fn_dashboard_avance_competencia",
  "fn_dashboard_avance_competencia",
  [
    { key: "p_documento", parser: toStringOrNull },
    { key: "p_id_ficha", parser: toIntOrNull },
    { key: "p_id_competencia", parser: toIntOrNull },
  ]
);

buildFunctionRoute(
  "/api/fn_dashboard_aprobacion_programa",
  "fn_dashboard_aprobacion_programa",
  [
    { key: "p_id_programa", parser: toIntOrNull },
    { key: "p_fecha_desde", parser: toStringOrNull },
    { key: "p_fecha_hasta", parser: toStringOrNull },
  ]
);

buildFunctionRoute("/api/fn_busqueda_maestra", "fn_busqueda_maestra", [
  { key: "p_id_juicio", parser: toIntOrNull },
  { key: "p_id_tipo_juicio", parser: toIntOrNull },
  { key: "p_codigo_juicio", parser: toStringOrNull },
  { key: "p_fecha_desde", parser: toStringOrNull },
  { key: "p_fecha_hasta", parser: toStringOrNull },
  { key: "p_documento_aprendiz", parser: toStringOrNull },
  { key: "p_tipo_documento", parser: toStringOrNull },
  { key: "p_nombre_aprendiz", parser: toStringOrNull },
  { key: "p_email_aprendiz", parser: toStringOrNull },
  { key: "p_id_ficha", parser: toIntOrNull },
  { key: "p_codigo_ficha", parser: toStringOrNull },
  { key: "p_id_programa", parser: toIntOrNull },
  { key: "p_codigo_programa", parser: toStringOrNull },
  { key: "p_nivel_formacion", parser: toStringOrNull },
  { key: "p_id_estado", parser: toIntOrNull },
  { key: "p_estado_aprendiz", parser: toStringOrNull },
  { key: "p_id_competencia", parser: toIntOrNull },
  { key: "p_codigo_competencia", parser: toStringOrNull },
  { key: "p_id_resultado", parser: toIntOrNull },
  { key: "p_codigo_resultado", parser: toStringOrNull },
  { key: "p_id_funcionario", parser: toIntOrNull },
  { key: "p_nombre_funcionario", parser: toStringOrNull },
  { key: "p_cargo_funcionario", parser: toStringOrNull },
  { key: "p_orden", parser: toStringOrNull },
  { key: "p_limite", parser: toIntOrNull },
  { key: "p_offset", parser: toIntOrNull },
]);

app.get("/api/options", async (_req, res) => {
  try {
    const fetchAll = async (table, cols) => {
      const { rows } = await pool.query(`SELECT ${cols.join(", ")} FROM ${table}`);
      return rows;
    };
    
    const [programas, fichas, competencias, estados] = await Promise.all([
      fetchAll("programa", ["id", "codigo_programa", "denominacion"]),
      fetchAll("ficha", ["id_ficha", "codigo_ficha"]),
      fetchAll("competencia", ["id_competencia", "codigo_competencia", "nombre_competencia", "id_programa"]),
      fetchAll("estado_aprendiz", ["id_estado", "codigo", "descripcion"])
    ]);
    
    res.json({ ok: true, data: { programas, fichas, competencias, estados } });
  } catch (error) {
    res.status(500).json({ ok: false, message: "Error fetching options", detail: error.message });
  }
});

app.delete("/api/database/clear", async (_req, res) => {
  try {
    await pool.query(`
      TRUNCATE TABLE juicios_evaluativos, resultado_aprendizaje, competencia, matricula, aprendiz, ficha, programa, funcionario, tipo_juicio, estado_aprendiz CASCADE;
    `);
    res.json({ ok: true, message: "Base de datos limpiada correctamente" });
  } catch (error) {
    console.error("Error clearing DB:", error);
    res.status(500).json({ ok: false, message: "Error al limpiar la base de datos", detail: error.message });
  }
});

app.delete("/api/ficha/:codigo", async (req, res) => {
  const client = await pool.connect();
  try {
    const { codigo } = req.params;
    await client.query("BEGIN");
    
    // 1. Obtener IDs de matrículas asociadas a la ficha
    const { rows: mats } = await client.query(`
      SELECT id_matricula FROM matricula 
      WHERE id_ficha IN (SELECT id_ficha FROM ficha WHERE codigo_ficha = $1)
    `, [codigo]);
    
    const matIds = mats.map(m => m.id_matricula);

    if (matIds.length > 0) {
      // 2. Borrar juicios evaluativos de esas matrículas
      await client.query(`DELETE FROM juicios_evaluativos WHERE id_matricula = ANY($1)`, [matIds]);
      // 3. Borrar matrículas
      await client.query(`DELETE FROM matricula WHERE id_matricula = ANY($1)`, [matIds]);
    }
    
    // 4. Borrar la ficha
    await client.query(`DELETE FROM ficha WHERE codigo_ficha = $1`, [codigo]);

    // 5. Opcional: Limpiar aprendices huérfanos (sin ninguna matrícula) 
    // para que el conteo del dashboard baje si ya no tienen ninguna ficha.
    await client.query(`DELETE FROM aprendiz WHERE documento NOT IN (SELECT id_aprendiz FROM matricula)`);
    
    await client.query("COMMIT");
    res.json({ ok: true, message: "Ficha y datos asociados eliminados correctamente" });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Error eliminando ficha:", error);
    res.status(500).json({ ok: false, message: "Error al eliminar la ficha", detail: error.message });
  } finally {
    client.release();
  }
});

app.get("/api/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, db: "connected" });
  } catch (error) {
    res.status(500).json({ ok: false, db: "error", detail: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Servidor activo en http://localhost:${PORT}`);
  console.log("DB Config:", { ...dbConfig, password: "******" });
});
