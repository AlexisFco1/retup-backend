// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · FORMULARIO DE ALTA DE USUARIO
// Ventana (dialog) para dar de alta a una persona. Al guardar muestra
// la contraseña temporal UNA sola vez, con botón para copiarla.
// Al terminar, refresca directorio, alertas y catálogo.
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '../../api/cliente';
import './FormularioAlta.css';

// ───────────── Forma de las respuestas del backend ─────────────
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

interface RespuestaAlta {
  success: boolean;
  usuario: { id: string; email: string; nombre: string; estado: string };
  password_temporal: string;
}

// ───────────── Datos del formulario ─────────────
interface DatosAlta {
  first_name: string;
  last_name_1: string;
  last_name_2: string;
  email: string;
  department_id: string;
  team_id: string;
  job_title: string;
  hire_date: string;
}

const FORMULARIO_VACIO: DatosAlta = {
  first_name: '',
  last_name_1: '',
  last_name_2: '',
  email: '',
  department_id: '',
  team_id: '',
  job_title: '',
  hire_date: '',
};

interface PropsFormularioAlta {
  /** Se llama cuando la ventana se ha cerrado */
  alCerrar: () => void;
}

export default function FormularioAlta({ alCerrar }: PropsFormularioAlta) {
  const refDialogo = useRef<HTMLDialogElement>(null);
  const queryClient = useQueryClient();
  const [datos, setDatos] = useState<DatosAlta>(FORMULARIO_VACIO);
  const [copiada, setCopiada] = useState(false);

  // Abrir la ventana en modo "modal" al aparecer
  useEffect(() => {
    const dialogo = refDialogo.current;
    if (dialogo && !dialogo.open) dialogo.showModal();
  }, []);

  // Departamentos y equipos de la empresa (solo los activos)
  const catalogo = useQuery({
    queryKey: ['mantenimiento', 'catalogo'],
    queryFn: () => apiFetch<RespuestaCatalogo>('/dashboard/mantenimiento/catalogo'),
  });
  const departamentos = (catalogo.data?.datos ?? []).filter((d) => d.activo);
  const equiposDelDepartamento =
    departamentos.find((d) => d.id === datos.department_id)?.equipos.filter((e) => e.activo) ?? [];

  // Envío al backend
  const alta = useMutation({
    mutationFn: (d: DatosAlta) =>
      apiFetch<RespuestaAlta>('/dashboard/mantenimiento/usuarios', {
        metodo: 'POST',
        cuerpo: {
          first_name: d.first_name,
          last_name_1: d.last_name_1,
          last_name_2: d.last_name_2 || null,
          email: d.email,
          department_id: d.department_id || null,
          team_id: d.team_id || null,
          job_title: d.job_title || null,
          hire_date: d.hire_date || null,
        },
      }),
    onSuccess: () => {
      // Todo lo que empieza por 'mantenimiento' se vuelve a pedir (directorio, alertas, catálogo)
      void queryClient.invalidateQueries({ queryKey: ['mantenimiento'] });
    },
  });

  function cambiar(campo: keyof DatosAlta, valor: string) {
    setDatos((anterior) => ({
      ...anterior,
      [campo]: valor,
      // Si cambia el departamento, el equipo elegido deja de valer
      ...(campo === 'department_id' ? { team_id: '' } : {}),
    }));
  }

  async function copiarPassword(password: string) {
    try {
      await navigator.clipboard.writeText(password);
      setCopiada(true);
    } catch {
      setCopiada(false);
    }
  }

  function darDeAltaOtra() {
    alta.reset();
    setDatos(FORMULARIO_VACIO);
    setCopiada(false);
  }

  function cerrar() {
    refDialogo.current?.close();
  }

  return (
    <dialog
      ref={refDialogo}
      className="alta"
      aria-labelledby="alta-titulo"
      onClose={alCerrar}
      onCancel={(ev) => {
        // Con Esc no se cierra mientras guarda ni mientras muestra la contraseña
        if (alta.isPending || alta.isSuccess) ev.preventDefault();
      }}
    >
      {alta.isSuccess ? (
        // ───────────── Resultado: contraseña temporal (solo esta vez) ─────────────
        <div className="alta__contenido">
          <h2 id="alta-titulo" className="alta__titulo">
            ✅ Persona dada de alta
          </h2>
          <p className="alta__persona">
            <strong>{alta.data.usuario.nombre}</strong>
            <span>{alta.data.usuario.email}</span>
          </p>

          <p className="alta__explicacion">
            Esta es su <strong>contraseña temporal</strong>. <strong>Solo se muestra ahora</strong>:
            cópiala y entrégasela por un canal seguro. Cuando entre por primera vez en la app, pasará
            de <em>Invitado</em> a <em>Activo</em>.
          </p>

          <div className="alta__password">
            <code>{alta.data.password_temporal}</code>
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => copiarPassword(alta.data.password_temporal)}
            >
              {copiada ? '¡Copiada!' : 'Copiar'}
            </button>
          </div>

          <div className="alta__acciones">
            <button type="button" className="alta__boton alta__boton--secundario" onClick={darDeAltaOtra}>
              Dar de alta a otra persona
            </button>
            <button type="button" className="alta__boton" onClick={cerrar}>
              Hecho, ya la he guardado
            </button>
          </div>
        </div>
      ) : (
        // ───────────── Formulario ─────────────
        <form
          className="alta__contenido"
          onSubmit={(ev) => {
            ev.preventDefault();
            alta.mutate(datos);
          }}
        >
          <h2 id="alta-titulo" className="alta__titulo">
            Dar de alta a una persona
          </h2>
          <p className="alta__explicacion">
            Se creará su cuenta con una contraseña temporal y quedará como <em>Invitado</em> hasta que
            entre por primera vez en la app. Los campos con * son obligatorios.
          </p>

          <div className="alta__rejilla">
            <label className="alta__campo">
              <span>Nombre *</span>
              <input
                required
                maxLength={60}
                autoFocus
                value={datos.first_name}
                onChange={(ev) => cambiar('first_name', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Primer apellido *</span>
              <input
                required
                maxLength={60}
                value={datos.last_name_1}
                onChange={(ev) => cambiar('last_name_1', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Segundo apellido</span>
              <input
                maxLength={60}
                value={datos.last_name_2}
                onChange={(ev) => cambiar('last_name_2', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Email *</span>
              <input
                required
                type="email"
                autoComplete="off"
                value={datos.email}
                onChange={(ev) => cambiar('email', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Departamento</span>
              <select
                value={datos.department_id}
                onChange={(ev) => cambiar('department_id', ev.target.value)}
                disabled={catalogo.isPending}
              >
                <option value="">{catalogo.isPending ? 'Cargando…' : 'Sin departamento'}</option>
                {departamentos.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.nombre}
                  </option>
                ))}
              </select>
            </label>

            <label className="alta__campo">
              <span>Equipo</span>
              <select
                value={datos.team_id}
                onChange={(ev) => cambiar('team_id', ev.target.value)}
                disabled={!datos.department_id || equiposDelDepartamento.length === 0}
              >
                <option value="">
                  {!datos.department_id
                    ? 'Elige antes un departamento'
                    : equiposDelDepartamento.length === 0
                      ? 'Este departamento no tiene equipos'
                      : 'Sin equipo'}
                </option>
                {equiposDelDepartamento.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.nombre}
                    {e.jefe ? ` (jefe: ${e.jefe})` : ''}
                  </option>
                ))}
              </select>
            </label>

            <label className="alta__campo">
              <span>Cargo</span>
              <input
                maxLength={120}
                value={datos.job_title}
                onChange={(ev) => cambiar('job_title', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Fecha de ingreso</span>
              <input
                type="date"
                value={datos.hire_date}
                onChange={(ev) => cambiar('hire_date', ev.target.value)}
              />
            </label>
          </div>

          {catalogo.isError && (
            <p className="alta__error" role="alert">
              No se pudieron cargar los departamentos. Puedes dar de alta sin departamento y asignarlo
              después.
            </p>
          )}

          {alta.isError && (
            <p className="alta__error" role="alert">
              ❌ {alta.error.message}
            </p>
          )}

          <div className="alta__acciones">
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={cerrar}
              disabled={alta.isPending}
            >
              Cancelar
            </button>
            <button type="submit" className="alta__boton" disabled={alta.isPending}>
              {alta.isPending ? 'Creando…' : 'Dar de alta'}
            </button>
          </div>
        </form>
      )}
    </dialog>
  );
}