// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · DEPARTAMENTOS Y EQUIPOS
// Ventana para crear, renombrar y desactivar/reactivar departamentos
// y equipos de la empresa. Las reglas (nombres repetidos, no desactivar
// con personas activas…) las aplica el backend; aquí se muestran sus avisos.
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '../../api/cliente';
import './FormularioAlta.css';
import './DepartamentosEquipos.css';

// ───────────── Catálogo ─────────────
interface EquipoCatalogo {
  id: string;
  nombre: string;
  activo: boolean;
  jefe_id: string | null;
  jefe: string | null;
  integrantes: number;
}

interface DepartamentoCatalogo {
  id: string;
  nombre: string;
  activo: boolean;
  personas: number;
  equipos: EquipoCatalogo[];
}

interface RespuestaCatalogo {
  success: boolean;
  datos: DepartamentoCatalogo[];
}

// ───────────── Operaciones contra el backend ─────────────
interface Cambios {
  nombre?: string;
  activo?: boolean;
}

type Operacion =
  | { tipo: 'crear-departamento'; nombre: string }
  | { tipo: 'crear-equipo'; nombre: string; departmentId: string }
  | { tipo: 'modificar-departamento'; id: string; cambios: Cambios }
  | { tipo: 'modificar-equipo'; id: string; cambios: Cambios };

const BASE = '/dashboard/mantenimiento';

function ejecutar(op: Operacion): Promise<{ success: boolean }> {
  switch (op.tipo) {
    case 'crear-departamento':
      return apiFetch(`${BASE}/departamentos`, { metodo: 'POST', cuerpo: { nombre: op.nombre } });
    case 'crear-equipo':
      return apiFetch(`${BASE}/equipos`, {
        metodo: 'POST',
        cuerpo: { nombre: op.nombre, department_id: op.departmentId },
      });
    case 'modificar-departamento':
      return apiFetch(`${BASE}/departamentos/${op.id}`, { metodo: 'PUT', cuerpo: op.cambios });
    case 'modificar-equipo':
      return apiFetch(`${BASE}/equipos/${op.id}`, { metodo: 'PUT', cuerpo: op.cambios });
  }
}

/** Qué nombre se está editando ahora mismo (solo uno a la vez) */
interface Edicion {
  tipo: 'departamento' | 'equipo';
  id: string;
  nombre: string;
}

// ───────────── Campo de nombre en línea (renombrar / nuevo equipo) ─────────────
interface PropsCampoNombre {
  valor: string;
  etiqueta: string;
  ocupado: boolean;
  alCambiar: (valor: string) => void;
  alGuardar: () => void;
  alCancelar: () => void;
}

function CampoNombre({ valor, etiqueta, ocupado, alCambiar, alGuardar, alCancelar }: PropsCampoNombre) {
  return (
    <form
      className="deq__editor"
      onSubmit={(ev) => {
        ev.preventDefault();
        alGuardar();
      }}
    >
      <input
        autoFocus
        aria-label={etiqueta}
        placeholder={etiqueta}
        maxLength={80}
        value={valor}
        onChange={(ev) => alCambiar(ev.target.value)}
      />
      <button type="submit" className="alta__boton" disabled={ocupado || !valor.trim()}>
        Guardar
      </button>
      <button type="button" className="alta__boton alta__boton--secundario" onClick={alCancelar} disabled={ocupado}>
        Cancelar
      </button>
    </form>
  );
}

// ───────────── Ventana ─────────────
interface PropsDepartamentosEquipos {
  alCerrar: () => void;
}

export default function DepartamentosEquipos({ alCerrar }: PropsDepartamentosEquipos) {
  const refDialogo = useRef<HTMLDialogElement>(null);
  const queryClient = useQueryClient();

  const [verDesactivados, setVerDesactivados] = useState(false);
  const [nuevoDepartamento, setNuevoDepartamento] = useState('');
  const [edicion, setEdicion] = useState<Edicion | null>(null);
  const [nuevoEquipoEn, setNuevoEquipoEn] = useState<string | null>(null);
  const [nombreNuevoEquipo, setNombreNuevoEquipo] = useState('');

  useEffect(() => {
    const dialogo = refDialogo.current;
    if (dialogo && !dialogo.open) dialogo.showModal();
  }, []);

  const catalogo = useQuery({
    queryKey: ['mantenimiento', 'catalogo'],
    queryFn: () => apiFetch<RespuestaCatalogo>(`${BASE}/catalogo`),
  });

  const operacion = useMutation({
    mutationFn: ejecutar,
    onSuccess: () => {
      // Se refrescan catálogo, directorio y alertas
      void queryClient.invalidateQueries({ queryKey: ['mantenimiento'] });
      setEdicion(null);
      setNuevoEquipoEn(null);
      setNombreNuevoEquipo('');
      setNuevoDepartamento('');
    },
  });
  const ocupado = operacion.isPending;

  const todos = catalogo.data?.datos ?? [];
  const visibles = todos.filter((d) => verDesactivados || d.activo);
  const hayDesactivados = todos.some((d) => !d.activo || d.equipos.some((e) => !e.activo));

  function empezarEdicion(tipo: Edicion['tipo'], id: string, nombre: string) {
    operacion.reset();
    setNuevoEquipoEn(null);
    setEdicion({ tipo, id, nombre });
  }

  function guardarEdicion() {
    if (!edicion) return;
    const nombre = edicion.nombre.trim();
    if (!nombre) return;
    operacion.mutate(
      edicion.tipo === 'departamento'
        ? { tipo: 'modificar-departamento', id: edicion.id, cambios: { nombre } }
        : { tipo: 'modificar-equipo', id: edicion.id, cambios: { nombre } },
    );
  }

  function empezarNuevoEquipo(departmentId: string) {
    operacion.reset();
    setEdicion(null);
    setNombreNuevoEquipo('');
    setNuevoEquipoEn(departmentId);
  }

  return (
    <dialog
      ref={refDialogo}
      className="alta deq"
      aria-labelledby="deq-titulo"
      onClose={alCerrar}
      onCancel={(ev) => {
        // Esc: si se está editando algo, cancela esa edición en vez de cerrar
        if (ocupado) {
          ev.preventDefault();
        } else if (edicion || nuevoEquipoEn) {
          ev.preventDefault();
          setEdicion(null);
          setNuevoEquipoEn(null);
        }
      }}
    >
      <div className="alta__contenido">
        <h2 id="deq-titulo" className="alta__titulo">
          Departamentos y equipos
        </h2>
        <p className="alta__explicacion">
          Un departamento o equipo desactivado deja de aparecer al dar de alta o editar personas, pero
          se conserva para los indicadores de meses anteriores. Solo se puede desactivar si no tiene
          personas activas.
        </p>

        {/* ── Crear departamento ── */}
        <form
          className="deq__editor"
          onSubmit={(ev) => {
            ev.preventDefault();
            const nombre = nuevoDepartamento.trim();
            if (nombre) operacion.mutate({ tipo: 'crear-departamento', nombre });
          }}
        >
          <input
            aria-label="Nombre del nuevo departamento"
            placeholder="Nombre del nuevo departamento"
            maxLength={80}
            value={nuevoDepartamento}
            onChange={(ev) => setNuevoDepartamento(ev.target.value)}
          />
          <button type="submit" className="alta__boton" disabled={ocupado || !nuevoDepartamento.trim()}>
            + Crear departamento
          </button>
        </form>

        {operacion.isError && (
          <p className="alta__error" role="alert">
            ❌ {operacion.error.message}
          </p>
        )}

        {/* ── Lista ── */}
        {catalogo.isPending ? (
          <p className="deq__mensaje">⏳ Cargando departamentos…</p>
        ) : catalogo.isError ? (
          <p className="alta__error" role="alert">
            ❌ {catalogo.error.message}
          </p>
        ) : visibles.length === 0 ? (
          <p className="deq__mensaje">Todavía no hay departamentos. Crea el primero arriba.</p>
        ) : (
          <ul className={`deq__lista${ocupado ? ' deq__lista--ocupada' : ''}`}>
            {visibles.map((d) => {
              const equipos = d.equipos.filter((e) => verDesactivados || e.activo);
              const equiposActivos = d.equipos.filter((e) => e.activo).length;
              const editandoDepartamento = edicion?.tipo === 'departamento' && edicion.id === d.id;

              return (
                <li key={d.id} className={`deq__departamento${d.activo ? '' : ' deq--inactivo'}`}>
                  {/* Fila del departamento */}
                  <div className="deq__fila">
                    {editandoDepartamento && edicion ? (
                      <CampoNombre
                        valor={edicion.nombre}
                        etiqueta="Nuevo nombre del departamento"
                        ocupado={ocupado}
                        alCambiar={(valor) => setEdicion({ ...edicion, nombre: valor })}
                        alGuardar={guardarEdicion}
                        alCancelar={() => setEdicion(null)}
                      />
                    ) : (
                      <>
                        <div className="deq__nombre">
                          <strong>{d.nombre}</strong>
                          {!d.activo && <span className="deq__etiqueta">Desactivado</span>}
                          <span className="deq__detalle">
                            {d.personas} {d.personas === 1 ? 'persona' : 'personas'} · {equiposActivos}{' '}
                            {equiposActivos === 1 ? 'equipo activo' : 'equipos activos'}
                          </span>
                        </div>
                        <div className="deq__botones">
                          <button
                            type="button"
                            className="deq__boton"
                            onClick={() => empezarEdicion('departamento', d.id, d.nombre)}
                            disabled={ocupado}
                          >
                            Renombrar
                          </button>
                          <button
                            type="button"
                            className="deq__boton"
                            onClick={() =>
                              operacion.mutate({
                                tipo: 'modificar-departamento',
                                id: d.id,
                                cambios: { activo: !d.activo },
                              })
                            }
                            disabled={ocupado}
                          >
                            {d.activo ? 'Desactivar' : 'Reactivar'}
                          </button>
                        </div>
                      </>
                    )}
                  </div>

                  {/* Equipos del departamento */}
                  <ul className="deq__equipos">
                    {equipos.length === 0 && <li className="deq__mensaje">Sin equipos</li>}
                    {equipos.map((e) => {
                      const editandoEquipo = edicion?.tipo === 'equipo' && edicion.id === e.id;
                      return (
                        <li key={e.id} className={`deq__fila deq__fila--equipo${e.activo ? '' : ' deq--inactivo'}`}>
                          {editandoEquipo && edicion ? (
                            <CampoNombre
                              valor={edicion.nombre}
                              etiqueta="Nuevo nombre del equipo"
                              ocupado={ocupado}
                              alCambiar={(valor) => setEdicion({ ...edicion, nombre: valor })}
                              alGuardar={guardarEdicion}
                              alCancelar={() => setEdicion(null)}
                            />
                          ) : (
                            <>
                              <div className="deq__nombre">
                                <strong>{e.nombre}</strong>
                                {!e.activo && <span className="deq__etiqueta">Desactivado</span>}
                                <span className="deq__detalle">
                                  {e.integrantes} {e.integrantes === 1 ? 'integrante' : 'integrantes'} · Jefe:{' '}
                                  {e.jefe ?? 'sin asignar'}
                                </span>
                              </div>
                              <div className="deq__botones">
                                <button
                                  type="button"
                                  className="deq__boton"
                                  onClick={() => empezarEdicion('equipo', e.id, e.nombre)}
                                  disabled={ocupado}
                                >
                                  Renombrar
                                </button>
                                <button
                                  type="button"
                                  className="deq__boton"
                                  onClick={() =>
                                    operacion.mutate({
                                      tipo: 'modificar-equipo',
                                      id: e.id,
                                      cambios: { activo: !e.activo },
                                    })
                                  }
                                  disabled={ocupado}
                                >
                                  {e.activo ? 'Desactivar' : 'Reactivar'}
                                </button>
                              </div>
                            </>
                          )}
                        </li>
                      );
                    })}
                  </ul>

                  {/* Añadir equipo (solo en departamentos activos) */}
                  {d.activo &&
                    (nuevoEquipoEn === d.id ? (
                      <div className="deq__nuevo-equipo">
                        <CampoNombre
                          valor={nombreNuevoEquipo}
                          etiqueta="Nombre del nuevo equipo"
                          ocupado={ocupado}
                          alCambiar={setNombreNuevoEquipo}
                          alGuardar={() => {
                            const nombre = nombreNuevoEquipo.trim();
                            if (nombre) operacion.mutate({ tipo: 'crear-equipo', nombre, departmentId: d.id });
                          }}
                          alCancelar={() => setNuevoEquipoEn(null)}
                        />
                      </div>
                    ) : (
                      <button
                        type="button"
                        className="deq__anadir"
                        onClick={() => empezarNuevoEquipo(d.id)}
                        disabled={ocupado}
                      >
                        + Añadir equipo
                      </button>
                    ))}
                </li>
              );
            })}
          </ul>
        )}

        {/* ── Pie ── */}
        <div className="deq__pie">
          <label className="deq__casilla">
            <input
              type="checkbox"
              checked={verDesactivados}
              onChange={(ev) => setVerDesactivados(ev.target.checked)}
              disabled={!hayDesactivados}
            />
            Mostrar desactivados
          </label>
          <button
            type="button"
            className="alta__boton"
            onClick={() => refDialogo.current?.close()}
            disabled={ocupado}
          >
            Cerrar
          </button>
        </div>
      </div>
    </dialog>
  );
}