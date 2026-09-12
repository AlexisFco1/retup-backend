import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pildora_model.dart';
import '../models/reto_model.dart';
import '../providers/pildora_provider.dart';
import '../providers/auth_provider.dart';
import 'pildora_detail_screen.dart';

class PillorasListScreen extends StatefulWidget {
  final Reto reto;

  const PillorasListScreen({
    Key? key,
    required this.reto,
  }) : super(key: key);

  @override
  State<PillorasListScreen> createState() => _PillorasListScreenState();
}

class _PillorasListScreenState extends State<PillorasListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PildoraProvider>().cargarPildorasDelReto(widget.reto.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reto.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<PildoraProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text('Error: ${provider.errorMessage}'),
            );
          }

          if (provider.pildoras.isEmpty) {
            return const Center(
              child: Text('No hay píldoras disponibles para este reto'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pildoras.length,
            itemBuilder: (context, index) {
              final pildora = provider.pildoras[index];
              return GestureDetector(
                onTap: userId != null
                    ? () {
                        provider.seleccionarPildora(pildora, userId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PildoraDetailScreen(
                              pildora: pildora,
                              retoTitle: widget.reto.title,
                              retoId: widget.reto.id,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Número de píldora
                        Text(
                          'Píldora ${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Título
                        Text(
                          pildora.titulo ?? 'Sin título',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Descripción
                        Text(
                          pildora.descripcion ?? 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Botón de iniciar
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.blue[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
