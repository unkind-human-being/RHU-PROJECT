const dotenv = require("dotenv");
const mongoose = require("mongoose");

dotenv.config();

const RHU = require("../models/RHU");
const Barangay = require("../models/Barangay");
const { connectDatabase, closeDatabase } = require("../config/db");

const barangayNamesByRhuCode = {
  rhu_simunul: [
    "Bagid",
    "Bakong",
    "Boheh Indangan (Tubig Indangan)",
    "Doh-Tong",
    "Maruwa",
    "Mongkay",
    "Pagasinan",
    "Panglima Mastul",
    "Sukah-Bulan",
    "Tampakan (Poblacion)",
    "Tonggusong",
    "Ubol",
    "Timundon",
    "Manuk Mangkaw",
    "Luuk Datan",
  ],

  rhu_languyan: [
    "Bakong",
    "Bas-bas Proper",
    "Basnunuk",
    "Darussalam",
    "Languyan Proper (Poblacion)",
    "Maraning",
    "Simalak",
    "Tuhog-Tuhog",
    "Tumahubong",
    "Tumbagaan",
    "Parang Pantay",
    "Adnin",
    "Bakaw-bakaw",
    "BasLikud",
    "Jakarta (Lookan Latuan)",
    "Kalupag",
    "Kiniktal",
    "Marang-marang",
    "Sikullis",
    "Tubig Dakula (Bohe Mahiya)",
  ],

  rhu_mapun: [
    "Boki",
    "Duhul Batu",
    "Iruk-Iruk",
    "Guppah",
    "Kompang",
    "Liyubud (Poblacion)",
    "Lubbak Parang",
    "Lupa Pula",
    "Mahalu",
    "Pawan",
    "Sapah",
    "Sikub",
    "Tabulian",
    "Tanduan",
    "Umus Mataha",
  ],

  rhu_turtle_island: ["Poblacion", "Likud Bakkaw"],

  rhu_sitangkai: [
    "Poblacion",
    "Panglima Alari",
    "Datu Puti",
    "South Larap",
    "Sipangkot",
    "Imam Sapie",
    "Tongmageng",
    "Tungusong",
    "North Larap",
  ],

  rhu_south_ubian: [
    "Babagan",
    "Bengkol",
    "Bintawlan",
    "Bohe",
    "Bubuan",
    "Bunay Bunay Tong",
    "Bunay Bunay Lookan",
    "Bunay Bunay Center",
    "Lahad Dampung",
    "East Talisay",
    "Nunuk",
    "Laitan",
    "Lambi-Lambian",
    "Laud",
    "Likud Tabawan",
    "Nusa-Nusa",
    "Nusa",
    "Pampang",
    "Putat",
    "Sollogan",
    "Talisay",
    "Tampakan Dampong",
    "Tinda-Tindahan",
    "Tong Tampakan",
    "Tubig Dayang Center",
    "Tubig Dayang Riverside",
    "Tubig Dayang",
    "Tukkai",
    "Unas-Unas",
    "Likud Dampong",
    "Tangngah",
  ],

  rhu_sapa_sapa: [
    "Baldatal Islam",
    "Butun",
    "Dalo-dalo",
    "Kohec",
    "Lakit-lakit",
    "Latuan",
    "Look Natuh",
    "Lookan Banaran",
    "Lookan Latuan",
    "Malanta",
    "Mantabuan Tabunan",
    "Nunuk Likud Sikubong",
    "Palate Gadjaminah",
    "Pamasan",
    "Sapa-Sapa (Poblacion)",
    "Sapaat",
    "Sukah-sukah",
    "Tabunan Likud Sikubong",
    "Tangngah",
    "Tapian Bohe North",
    "Tapian Bohe South",
    "Tonggusong Banaran",
    "Tup-tup Banaran",
  ],

  rhu_sibutu: [
    "Ambulong Sapal",
    "Datu Amilhamja Jaafar",
    "Hadji Imam Bidin",
    "Hadji Mohtar Sulayman",
    "Hadji Taha",
    "Imam Hadji Mohammad",
    "Ligayan",
    "Nunukan",
    "Sheik Makdum",
    "Sibutu (Poblacion)",
    "Talisay",
    "Tandu Banak",
    "Taungoh",
    "Tongehat",
    "Tongsibalo",
    "Ungus-ungus",
  ],

  rhu_bongao: [
    "Bongao Poblacion (sentro)",
    "Ipil",
    "Kamagong",
    "Karungdong",
    "Lagasan",
    "Lakit Lakit",
    "Lamion",
    "Lapid Lapid",
    "Lato Lato",
    "Luuk Pandan",
    "Luuk Tulay",
    "Malassa",
    "Mandulan",
    "Masantong",
    "Montay Montay",
    "Nalil",
    "Pababag",
    "Pag-asa",
    "Pagasinan",
    "Pagatpat",
    "Pahut",
    "Pakias",
    "Paniongan",
    "Pasiagan",
    "Sanga-sanga",
    "Silubog",
    "Simandagit",
    "Sumangat",
    "Tarawakan",
    "Tongsinah",
    "Tubig Basag",
    "Tubig Tanah",
    "Tubig-Boh",
    "Tubig-Mampallam",
    "Ungus-ungus",
  ],

  rhu_panglima_sugala: [
    "Balimbing Proper",
    "Batu-batu (Bato-Bato / Poblacion)",
    "Bauno Garing",
    "Belatan Halu",
    "Buan",
    "Dungon",
    "Karaha",
    "Kulape",
    "Liyaburan",
    "Luuk Buntal",
    "Magsaggaw",
    "Malacca",
    "Parangan",
    "Sumangday",
    "Tabunan",
    "Tundon",
    "Tungbangkaw",
  ],

  rhu_tandubas: [
    "Baliungan",
    "Ballak",
    "Butun",
    "Himbah",
    "Kakoong",
    "Kalang-kalang",
    "Kepeng",
    "Lahay-lahay",
    "Naungan",
    "Salamat",
    "Sallangan",
    "Sapa",
    "Sibakloon",
    "Silantup",
    "Tandubato",
    "Tangngah",
    "Tapian",
    "Tapian Sukah",
    "Taruk",
    "Tongbangkaw",
  ],
};

const rhuSeedData = [
  {
    name: "Bongao Rural Health Unit",
    code: "rhu_bongao",
    municipality: "Bongao",
    province: "Tawi-Tawi",
  },
  {
    name: "Sibutu Rural Health Unit",
    code: "rhu_sibutu",
    municipality: "Sibutu",
    province: "Tawi-Tawi",
  },
  {
    name: "Panglima Sugala Rural Health Unit",
    code: "rhu_panglima_sugala",
    municipality: "Panglima Sugala",
    province: "Tawi-Tawi",
  },
  {
    name: "Sapa-Sapa Rural Health Unit",
    code: "rhu_sapa_sapa",
    municipality: "Sapa-Sapa",
    province: "Tawi-Tawi",
  },
  {
    name: "Simunul Rural Health Unit",
    code: "rhu_simunul",
    municipality: "Simunul",
    province: "Tawi-Tawi",
  },
  {
    name: "Tandubas Rural Health Unit",
    code: "rhu_tandubas",
    municipality: "Tandubas",
    province: "Tawi-Tawi",
  },
  {
    name: "Turtle Islands Rural Health Unit",
    code: "rhu_turtle_island",
    municipality: "Turtle Islands",
    province: "Tawi-Tawi",
  },
  {
    name: "South Ubian Rural Health Unit",
    code: "rhu_south_ubian",
    municipality: "South Ubian",
    province: "Tawi-Tawi",
  },
  {
    name: "Sitangkai Rural Health Unit",
    code: "rhu_sitangkai",
    municipality: "Sitangkai",
    province: "Tawi-Tawi",
  },
  {
    name: "Languyan Rural Health Unit",
    code: "rhu_languyan",
    municipality: "Languyan",
    province: "Tawi-Tawi",
  },
  {
    name: "Mapun Rural Health Unit",
    code: "rhu_mapun",
    municipality: "Mapun",
    province: "Tawi-Tawi",
  },
];

const seedRHUs = async () => {
  try {
    await connectDatabase();

    console.log("Starting RHU and barangay seed process...");

    const seededRHUs = [];
    let totalBarangaysSeeded = 0;

    for (const rhuData of rhuSeedData) {
      const barangays = barangayNamesByRhuCode[rhuData.code] || [];

      const rhu = await RHU.findOneAndUpdate(
        { code: rhuData.code },
        {
          $set: {
            name: rhuData.name,
            municipality: rhuData.municipality,
            province: rhuData.province,
            barangayCount: barangays.length,
            isActive: true,
          },
          $setOnInsert: {
            code: rhuData.code,
            address: "",
            contactNumber: "",
            email: "",
            createdBy: null,
          },
        },
        {
          upsert: true,
          new: true,
          runValidators: true,
          setDefaultsOnInsert: true,
        }
      );

      seededRHUs.push(rhu);

      console.log(`Seeded RHU: ${rhu.name} (${rhu.code})`);

      for (let index = 0; index < barangays.length; index += 1) {
        const barangayName = barangays[index];
        const barangayNumber = index + 1;
        const barangayCode = `${rhu.code}_barangay_${barangayNumber}`;

        await Barangay.findOneAndUpdate(
          {
            rhu: rhu._id,
            code: barangayCode,
          },
          {
            $set: {
              name: barangayName,
              municipality: rhu.municipality,
              province: rhu.province,
              address: `${barangayName}, ${rhu.municipality}, ${rhu.province}`,
              isActive: true,
            },
            $setOnInsert: {
              code: barangayCode,
              rhu: rhu._id,
              contactNumber: "",
              assignedHealthWorkers: [],
              createdBy: null,
            },
          },
          {
            upsert: true,
            new: true,
            runValidators: true,
            setDefaultsOnInsert: true,
          }
        );

        totalBarangaysSeeded += 1;
      }

      console.log(
        `Seeded barangays for ${rhu.municipality}: ${barangays.length}`
      );
    }

    console.log("----------------------------------------");
    console.log("RHU and barangay seed completed successfully.");
    console.log(`Total RHUs seeded: ${seededRHUs.length}`);
    console.log(`Total barangays seeded/updated: ${totalBarangaysSeeded}`);
    console.log("----------------------------------------");

    await closeDatabase();
    process.exit(0);
  } catch (error) {
    console.error("RHU and barangay seed failed.");
    console.error(error.message);

    if (error.errors) {
      for (const field of Object.keys(error.errors)) {
        console.error(`${field}: ${error.errors[field].message}`);
      }
    }

    await mongoose.connection.close();
    process.exit(1);
  }
};

seedRHUs();