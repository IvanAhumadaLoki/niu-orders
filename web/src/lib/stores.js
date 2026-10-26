// Tiendas de la franquicia (dataset de la prueba), usadas para el filtro por
// tienda. Coinciden con los seeds de la API (api/db/seeds.rb).
//
// Concesión consciente: la API no expone un listado de restaurantes, así que
// se declaran aquí. Si las tiendas cambiaran con frecuencia, lo correcto sería
// agregar un endpoint (GET /api/v1/restaurants) y leerlas desde allí.
export const STORES = [
  { id: 1, code: "PROV", name: "Niu Foods Providencia" },
  { id: 2, code: "LCON", name: "Niu Foods Las Condes" },
  { id: 3, code: "NUNO", name: "Niu Foods Ñuñoa" },
];