import bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { getDb } from './db.js';
import logger from '../utils/logger.js';

function generateCode() {
  return randomBytes(3).toString('hex').toUpperCase();
}

export function seedDemoData() {
  const db = getDb();

  if (db.prepare("SELECT id FROM users WHERE email = 'alice@carebridge.demo'").get()) return;

  logger.info('Seeding demo data…');
  const hash = bcrypt.hashSync('demo1234', 10);

  // ── Caregivers ────────────────────────────────────────────────────────────
  const cgInsert = (email, first, last) => {
    const ex = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (ex) {
      db.prepare('UPDATE users SET first_name = ?, last_name = ? WHERE id = ?').run(first, last, ex.id);
      return ex.id;
    }
    return db.prepare(
      "INSERT INTO users (email, password_hash, role, first_name, last_name) VALUES (?, ?, 'caregiver', ?, ?)"
    ).run(email, hash, first, last).lastInsertRowid;
  };

  const caregiverId  = cgInsert('caregiver@demo.com', 'Sarah', 'Mitchell');
  const cg2Id        = cgInsert('james@carebridge.demo', 'James', 'Rivera');
  const cg3Id        = cgInsert('priya@carebridge.demo', 'Priya', 'Nair');

  const demoPatients = [
    {
      email: 'alice@carebridge.demo', firstName: 'Alice', lastName: 'Johnson',
      dob: '1942-03-15', score: 45,
      gender: 'female', heightCm: 158, weightKg: 52.3,
      hearingNotes: 'Mild bilateral hearing loss — uses hearing aids in both ears. Speak clearly and face her when talking.',
      visionScore: '20/40 corrected — wears bifocal glasses. Larger text preferred.',
      aiCompanionName: 'Maya', aiCompanionGender: 'female',
      diagnoses: ['ALS – Stage 2', 'Hypertension'],
      allergies: ['Penicillin'],
      medicalHistory: 'Alice was diagnosed with ALS (Amyotrophic Lateral Sclerosis) in March 2022 after a 14-month diagnostic workup. She has a long-standing history of hypertension managed with Lisinopril since 2008. She is a retired schoolteacher and former marathon runner. No prior surgeries. Non-smoker. Occasional wine with dinner. Family history notable for cardiovascular disease (father, brother) and type 2 diabetes (mother).',
      emergencyContacts: [
        { name: 'Patricia Johnson', relation: 'Daughter', phone: '(312) 555-0192', isPrimary: true },
        { name: 'Michael Johnson', relation: 'Son', phone: '(773) 555-0347', isPrimary: false },
        { name: 'Dr. Renata Silva', relation: 'Primary Physician', phone: '(312) 555-8800', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Renata Silva', role: 'Neurologist', organization: 'Northwestern Memorial Hospital', phone: '(312) 555-8800' },
        { name: 'Sarah Mitchell', role: 'Primary Caregiver', organization: 'CareBridge', phone: '(312) 555-0011' },
        { name: 'Linda Park', role: 'Speech-Language Pathologist', organization: 'NorthShore SLP Services', phone: '(847) 555-0229' },
        { name: 'Tom Reeves', role: 'Physical Therapist', organization: 'Restore PT Group', phone: '(312) 555-0453' }
      ],
      meds: [
        { name: 'Riluzole',    dosage: '50mg',  frequency: 'Twice daily',  instructions: 'Take with or without food' },
        { name: 'Lisinopril',  dosage: '10mg',  frequency: 'Once daily',   instructions: 'Take in the morning' }
      ],
      checkins: [
        { energy:2, mood:3, pain:8, fatigue:9, appetite:3, hydration:4, notes:'Very difficult morning – breathing laboured, called RN' },
        { energy:3, mood:4, pain:7, fatigue:8, appetite:4, hydration:5, notes:'Feeling quite fatigued, struggled with lunch today' },
        { energy:4, mood:5, pain:6, fatigue:7, appetite:5, hydration:6, notes:'Better than yesterday – walked to kitchen with walker' },
        { energy:3, mood:4, pain:7, fatigue:8, appetite:4, hydration:5, notes:'Slept poorly, hands weaker than usual this morning' },
        { energy:4, mood:5, pain:6, fatigue:6, appetite:5, hydration:7, notes:'Afternoon nap helped; completed speech therapy exercises' },
        { energy:3, mood:4, pain:8, fatigue:8, appetite:3, hydration:4, notes:'Pain spike after physical therapy session' },
        { energy:4, mood:5, pain:6, fatigue:7, appetite:5, hydration:6, notes:'Engaged and talkative during caregiver visit' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',    content: 'Difficulty swallowing Riluzole this morning. Crushed and mixed with applesauce per protocol. Family notified.' },
        { cg: 'cg2', type: 'behavior',       content: 'Notably anxious about upcoming neurology appointment. Reviewed questions list together and practiced deep breathing.' },
        { cg: 'cg1', type: 'nutrition',      content: 'Consumed 60% of breakfast and 80% of lunch. Appetite improving since medication dose adjustment.' },
        { cg: 'cg3', type: 'communication',  content: 'Alice expressed frustration at declining speech clarity. Referred to SLP for updated AAC device evaluation.' },
        { cg: 'cg2', type: 'observation',    content: 'Bilateral hand grip strength noticeably weaker compared to last week assessment. Documented for neurology team.' },
        { cg: 'cg1', type: 'equipment',      content: 'Power wheelchair serviced today. New headrest positioning reduces fatigue in afternoon hours.' }
      ]
    },
    {
      email: 'robert@carebridge.demo', firstName: 'Robert', lastName: 'Chen',
      dob: '1958-07-22', score: 68,
      gender: 'male', heightCm: 172, weightKg: 78.1,
      hearingNotes: 'Hearing within normal limits. No aids required.',
      visionScore: '20/25 corrected — wears reading glasses only.',
      aiCompanionName: 'Sam', aiCompanionGender: 'male',
      diagnoses: ["Parkinson's Disease – Stage 3", 'Type 2 Diabetes'],
      allergies: ['Sulfa drugs'],
      medicalHistory: "Robert was diagnosed with Parkinson's Disease in 2018 following a two-year period of progressive resting tremor and bradykinesia. He also has a 10-year history of Type 2 Diabetes managed with Metformin. Retired electrical engineer. Married with three adult children. Non-smoker. Moderate alcohol use (2-3 drinks/week). Prior surgeries: appendectomy (1995), right knee arthroscopy (2010). Family history: father had Parkinson's; mother had type 2 diabetes.",
      emergencyContacts: [
        { name: 'Linda Chen', relation: 'Spouse', phone: '(415) 555-0211', isPrimary: true },
        { name: 'Kevin Chen', relation: 'Son', phone: '(415) 555-0388', isPrimary: false },
        { name: 'Dr. Amir Patel', relation: 'Neurologist', phone: '(415) 555-7700', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Amir Patel', role: 'Neurologist', organization: 'UCSF Parkinson\'s Center', phone: '(415) 555-7700' },
        { name: 'Sarah Mitchell', role: 'Primary Caregiver', organization: 'CareBridge', phone: '(312) 555-0011' },
        { name: 'James Rivera', role: 'Occupational Therapist', organization: 'Bay Area OT Associates', phone: '(415) 555-0122' },
        { name: 'Dr. Mei Lin', role: 'Endocrinologist', organization: 'UCSF Diabetes Center', phone: '(415) 555-6600' }
      ],
      meds: [
        { name: 'Levodopa/Carbidopa', dosage: '100/25mg', frequency: 'Three times daily', instructions: 'Take 30 min before meals' },
        { name: 'Metformin',          dosage: '500mg',     frequency: 'Twice daily',       instructions: 'Take with meals' },
        { name: 'Pramipexole',        dosage: '0.5mg',     frequency: 'Once at bedtime',   instructions: 'Take with water' }
      ],
      checkins: [
        { energy:6, mood:7, pain:4, fatigue:5, appetite:7, hydration:7, notes:'Good morning – mild tremors in right hand only' },
        { energy:7, mood:6, pain:3, fatigue:4, appetite:8, hydration:8, notes:'PT session went well; balance exercise completion rate high' },
        { energy:5, mood:5, pain:5, fatigue:6, appetite:6, hydration:7, notes:'Off episode around 11am before second dose – lasted ~45 min' },
        { energy:7, mood:8, pain:3, fatigue:4, appetite:7, hydration:8, notes:'Excellent session with DBS device check – settings optimised' },
        { energy:6, mood:6, pain:4, fatigue:5, appetite:6, hydration:7, notes:'Slight increase in resting tremor this afternoon' },
        { energy:7, mood:7, pain:3, fatigue:4, appetite:8, hydration:9, notes:"Attended grandson's soccer game – very uplifting for mood" },
        { energy:6, mood:8, pain:3, fatigue:4, appetite:7, hydration:8, notes:'Night sleep improved; Pramipexole at new timing working well' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',   content: 'Tremors significantly reduced since Levodopa dose adjustment. Walking noticeably steadier this afternoon.' },
        { cg: 'cg2', type: 'equipment',     content: 'Installed grab bars in bathroom shower. Robert practiced safe entry/exit technique three times successfully.' },
        { cg: 'cg3', type: 'question',      content: 'Robert asked about fall-prevention mat near bed. Ordered foam mat; scheduled occupational therapy assessment for home safety.' },
        { cg: 'cg1', type: 'nutrition',     content: 'Blood glucose 156 mg/dL pre-breakfast. Reviewed meal portion sizes and reduced evening carb serving.' },
        { cg: 'cg2', type: 'observation',   content: 'Significant "off" episode lasting 45 minutes before noon dose. Neurologist notified; considering dose timing adjustment.' },
        { cg: 'cg3', type: 'behavior',      content: "Showed interest in joining online Parkinson's support group. Helped him register and join first session." }
      ]
    },
    {
      email: 'maria@carebridge.demo', firstName: 'Maria', lastName: 'Garcia',
      dob: '1965-11-08', score: 82,
      gender: 'female', heightCm: 163, weightKg: 61.5,
      hearingNotes: 'No known hearing impairment.',
      visionScore: '20/20 corrected — wears contact lenses.',
      aiCompanionName: 'Aria', aiCompanionGender: 'female',
      diagnoses: ['MS – Relapsing-Remitting', 'Depression – in remission'],
      allergies: [],
      medicalHistory: 'Maria was diagnosed with Relapsing-Remitting Multiple Sclerosis in 2014 following an episode of optic neuritis. She has been in remission from depression since 2020 following successful CBT and Sertraline therapy. Works part-time as a marketing consultant. Married, two children. Non-smoker, alcohol-free since 2019. Prior surgeries: C-section (2001, 2004). Family history: mother has MS; no other notable conditions.',
      emergencyContacts: [
        { name: 'Carlos Garcia', relation: 'Husband', phone: '(305) 555-0144', isPrimary: true },
        { name: 'Rosa Mendez', relation: 'Sister', phone: '(305) 555-0267', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Fatima Hassan', role: 'Neurologist (MS Specialist)', organization: 'Miami MS Center', phone: '(305) 555-9900' },
        { name: 'Priya Nair', role: 'Care Coordinator', organization: 'CareBridge', phone: '(312) 555-0033' },
        { name: 'Dr. Susan Kowalski', role: 'Psychiatrist', organization: 'Wellness Mind Group', phone: '(305) 555-4411' }
      ],
      meds: [
        { name: 'Interferon Beta-1a', dosage: '30mcg',  frequency: 'Weekly injection', instructions: 'Rotate injection sites; administer Fridays' },
        { name: 'Sertraline',         dosage: '50mg',   frequency: 'Once daily',       instructions: 'Take in the morning with food' },
        { name: 'Vitamin D3',         dosage: '2000IU', frequency: 'Once daily',       instructions: 'Take with largest meal' }
      ],
      checkins: [
        { energy:8, mood:8, pain:2, fatigue:3, appetite:9, hydration:9, notes:'Great week – no flare-up symptoms' },
        { energy:7, mood:9, pain:2, fatigue:4, appetite:8, hydration:9, notes:'Started new MS support group today; very positive' },
        { energy:8, mood:8, pain:2, fatigue:3, appetite:9, hydration:8, notes:'Completed 30-min walk without fatigue; huge milestone' },
        { energy:6, mood:7, pain:4, fatigue:6, appetite:7, hydration:7, notes:'Mild fatigue after stressful work call; rested afternoon' },
        { energy:8, mood:9, pain:2, fatigue:3, appetite:9, hydration:9, notes:'Received positive report from MRI – no new lesions' },
        { energy:7, mood:8, pain:2, fatigue:4, appetite:8, hydration:8, notes:'Yoga session very helpful; continuing weekly' },
        { energy:8, mood:9, pain:1, fatigue:2, appetite:9, hydration:9, notes:'Best week in months – returned to part-time consulting work' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',   content: 'No relapse symptoms this week. Maria completed all self-care tasks independently. Mood excellent.' },
        { cg: 'cg3', type: 'communication', content: 'In-depth conversation about future planning. Maria expressed strong desire to return to part-time work in spring.' },
        { cg: 'cg2', type: 'observation',   content: 'MRI results reviewed with neurologist – no new lesions, current treatment plan continuing unchanged.' },
        { cg: 'cg1', type: 'nutrition',     content: 'Anti-inflammatory diet adherence excellent this month. Maria has created a meal prep routine that works for her schedule.' }
      ]
    },
    {
      email: 'betty@carebridge.demo', firstName: 'Betty', lastName: 'Okafor',
      dob: '1939-06-03', score: 38,
      gender: 'female', heightCm: 154, weightKg: 68.2,
      hearingNotes: 'Significant bilateral hearing loss. Wears behind-the-ear hearing aids — ensure batteries are fresh. Speak loudly and clearly, facing her directly.',
      visionScore: '20/80 — macular degeneration in left eye. Uses magnifying glass for reading. Avoid small text.',
      aiCompanionName: 'Grace', aiCompanionGender: 'female',
      diagnoses: ['COPD – Stage 3 Gold', 'Heart Failure – EF 35%', 'Atrial Fibrillation'],
      allergies: ['Aspirin', 'Iodine contrast'],
      medicalHistory: 'Betty has a 20-year history of COPD secondary to 40 pack-year smoking history (quit 2005). She developed heart failure with reduced ejection fraction (EF 35%) in 2020 following a NSTEMI. Atrial fibrillation diagnosed 2019, currently managed with Apixaban. Widowed. Four adult children. Three prior hospitalisations for acute COPD exacerbation (2021, 2022, 2023). Prior surgeries: cholecystectomy (1988), right hip replacement (2015).',
      emergencyContacts: [
        { name: 'Grace Okafor', relation: 'Daughter (Primary)', phone: '(404) 555-0177', isPrimary: true },
        { name: 'Charles Okafor Jr.', relation: 'Son', phone: '(404) 555-0322', isPrimary: false },
        { name: 'Dr. Marcus Webb', relation: 'Cardiologist', phone: '(404) 555-5500', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Marcus Webb', role: 'Cardiologist', organization: 'Emory Heart & Vascular', phone: '(404) 555-5500' },
        { name: 'Dr. Patricia Owens', role: 'Pulmonologist', organization: 'Emory Respiratory', phone: '(404) 555-6611' },
        { name: 'James Rivera', role: 'Palliative Care Nurse', organization: 'CareBridge', phone: '(312) 555-0022' },
        { name: 'Angela Moore', role: 'Registered Dietician', organization: 'Nutritional Wellness Group', phone: '(404) 555-0880' }
      ],
      meds: [
        { name: 'Tiotropium inhaler',  dosage: '18mcg',   frequency: 'Once daily',         instructions: 'Use Handihaler device every morning' },
        { name: 'Furosemide',          dosage: '40mg',     frequency: 'Once daily',         instructions: 'Take in the morning; monitor weight daily' },
        { name: 'Carvedilol',          dosage: '6.25mg',   frequency: 'Twice daily',        instructions: 'Take with food to reduce dizziness' },
        { name: 'Apixaban',            dosage: '5mg',      frequency: 'Twice daily',        instructions: 'Do not skip – stroke prevention for A-Fib' },
        { name: 'Spironolactone',      dosage: '25mg',     frequency: 'Once daily',         instructions: 'Monitor potassium levels monthly' }
      ],
      checkins: [
        { energy:2, mood:3, pain:6, fatigue:9, appetite:3, hydration:4, notes:'Very short of breath this morning – used nebuliser twice' },
        { energy:3, mood:3, pain:5, fatigue:8, appetite:3, hydration:4, notes:'2kg weight gain overnight – called cardiologist, diuretic dose increased' },
        { energy:2, mood:4, pain:6, fatigue:9, appetite:2, hydration:4, notes:'Breathless at rest; oxygen saturation 91% on room air – O2 started' },
        { energy:3, mood:4, pain:5, fatigue:8, appetite:3, hydration:5, notes:'Slightly better after increased furosemide; ankles less swollen' },
        { energy:3, mood:3, pain:6, fatigue:8, appetite:3, hydration:4, notes:'Night was very difficult – repositioned every 2 hours' },
        { energy:2, mood:3, pain:7, fatigue:9, appetite:2, hydration:3, notes:'Appetite very poor; accepted only soft foods and thickened fluids' },
        { energy:3, mood:5, pain:5, fatigue:7, appetite:4, hydration:5, notes:'Small improvement – sat in chair for 45 minutes this afternoon' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',   content: 'Oxygen saturation dropping to 89-91% on exertion. Supplemental O2 at 2L/min initiated; cardiologist notified.' },
        { cg: 'cg2', type: 'observation',   content: 'Bilateral pitting oedema to mid-calf noted. Weight up 2.1kg from yesterday. Furosemide dose increased per protocol order.' },
        { cg: 'cg3', type: 'nutrition',     content: 'Intake less than 30% at all meals for 3 days. Dietician referral placed; high-calorie supplement (Ensure) started twice daily.' },
        { cg: 'cg1', type: 'behavior',      content: 'Betty tearfully shared feeling like a burden. Spent time listening, validated feelings, and arranged pastoral care visit.' },
        { cg: 'cg2', type: 'equipment',     content: 'Hospital bed height repositioned; pressure-relief mattress overlay added. Skin integrity currently intact.' },
        { cg: 'cg3', type: 'communication', content: 'Advance care planning conversation held with Betty and her daughter. Betty affirmed DNR/DNI status. Documents updated in chart.' }
      ]
    },
    {
      email: 'james@carebridge.demo2', firstName: 'James', lastName: 'Whitmore',
      dob: '1950-09-14', score: 61,
      gender: 'male', heightCm: 178, weightKg: 80.5,
      hearingNotes: 'Mild high-frequency hearing loss in right ear. No hearing aids currently. Speak clearly on his left side.',
      visionScore: '20/30 corrected — wears progressive lenses.',
      aiCompanionName: 'Sam', aiCompanionGender: 'male',
      diagnoses: ['Stroke – left MCA (6 months post)', 'Dysphagia', 'Hypertension', 'Hyperlipidemia'],
      allergies: ['Warfarin (contraindicated – prior GI bleed)'],
      medicalHistory: 'James suffered a left middle cerebral artery ischemic stroke in December 2024 with resulting right-sided hemiparesis and expressive aphasia. He has a 15-year history of hypertension and hyperlipidemia. Prior GI bleed (2018) contraindicates warfarin — managed with Clopidogrel. Retired school principal. Widower, two adult daughters. Smoker until 2010 (25 pack-years). Prior surgeries: CABG x2 (2015).',
      emergencyContacts: [
        { name: 'Susan Whitmore', relation: 'Daughter', phone: '(617) 555-0199', isPrimary: true },
        { name: 'Anne Whitmore-Bell', relation: 'Daughter', phone: '(617) 555-0277', isPrimary: false },
        { name: 'Dr. Ingrid Larson', relation: 'Neurologist', phone: '(617) 555-4400', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Ingrid Larson', role: 'Neurologist', organization: 'Mass General Stroke Unit', phone: '(617) 555-4400' },
        { name: 'Sarah Mitchell', role: 'Primary Caregiver', organization: 'CareBridge', phone: '(312) 555-0011' },
        { name: 'Christine Lee', role: 'Speech-Language Pathologist', organization: 'Boston SLP Rehab', phone: '(617) 555-0588' },
        { name: 'Daniel Osei', role: 'Physical Therapist', organization: 'Spaulding Rehab', phone: '(617) 555-0699' }
      ],
      meds: [
        { name: 'Aspirin',       dosage: '81mg',    frequency: 'Once daily',  instructions: 'Take with food' },
        { name: 'Atorvastatin',  dosage: '40mg',    frequency: 'Once at night', instructions: 'Take at bedtime' },
        { name: 'Amlodipine',    dosage: '5mg',     frequency: 'Once daily',  instructions: 'Take in the morning' },
        { name: 'Clopidogrel',   dosage: '75mg',    frequency: 'Once daily',  instructions: 'Do not crush' }
      ],
      checkins: [
        { energy:6, mood:5, pain:3, fatigue:6, appetite:6, hydration:6, notes:'Good speech therapy session; repeated 8/10 words correctly' },
        { energy:5, mood:4, pain:3, fatigue:6, appetite:5, hydration:5, notes:'Frustrated with slow progress; mood lower today' },
        { energy:7, mood:7, pain:2, fatigue:5, appetite:7, hydration:7, notes:'Transferred from chair to bed independently for first time!' },
        { energy:6, mood:6, pain:3, fatigue:5, appetite:6, hydration:6, notes:'Right-hand grip exercises going well; squeeze ball routine complete' },
        { energy:6, mood:5, pain:4, fatigue:6, appetite:5, hydration:6, notes:'Mild headache in afternoon; BP checked: 148/92 – cardiologist aware' },
        { energy:7, mood:7, pain:2, fatigue:4, appetite:7, hydration:8, notes:'Video call with grandchildren lifted mood significantly' },
        { energy:6, mood:6, pain:3, fatigue:5, appetite:6, hydration:7, notes:'Completed full shower with minimal assist for first time' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',   content: 'Dysphagia improving with thickened liquids at IDDSI Level 3. No coughing or choking episodes this week.' },
        { cg: 'cg2', type: 'behavior',      content: 'James becoming frustrated with aphasia recovery pace. Connected with stroke survivors peer support group online.' },
        { cg: 'cg3', type: 'observation',   content: 'Right upper extremity motor function improving – extended arm and grasped cup independently today.' },
        { cg: 'cg1', type: 'nutrition',     content: 'All meals blended to appropriate consistency. Protein intake meeting targets. Weight stable at 78kg.' },
        { cg: 'cg2', type: 'communication', content: 'BP trending up over past 3 days: 145/90, 148/92, 150/94. Neurologist notified; antihypertensive dose under review.' },
        { cg: 'cg3', type: 'equipment',     content: 'AFO brace fitted today by orthotist. James practiced walking with quad cane in hallway – 12 metres without rest.' }
      ]
    },
    {
      email: 'dorothy@carebridge.demo', firstName: 'Dorothy', lastName: 'Nguyen',
      dob: '1945-02-28', score: 74,
      gender: 'female', heightCm: 155, weightKg: 58.0,
      hearingNotes: 'Moderate bilateral hearing loss — wears receiver-in-canal (RIC) hearing aids. Ensure aids are inserted before conversation. Speak slowly using simple sentences.',
      visionScore: '20/50 corrected — cataracts in both eyes, surgery pending. Prefers very large text and high-contrast colours.',
      aiCompanionName: 'Lily', aiCompanionGender: 'female',
      diagnoses: ["Alzheimer's Disease – Moderate Stage", 'Type 2 Diabetes', 'Osteoporosis'],
      allergies: ['Codeine'],
      medicalHistory: "Dorothy was diagnosed with Alzheimer's Disease in 2021 following progressive memory loss over 2 years. She has managed Type 2 Diabetes with oral medication since 2009, and osteoporosis since 2017 following a fragility fracture of the right wrist. Widowed 2020. Three adult children. Lives with daughter. Non-smoker, non-drinker. Prior surgeries: hysterectomy (1980), right wrist ORIF (2017). Family history: mother had dementia.",
      emergencyContacts: [
        { name: 'Linh Nguyen-Park', relation: 'Daughter (Primary Carer)', phone: '(408) 555-0133', isPrimary: true },
        { name: 'Thomas Nguyen', relation: 'Son', phone: '(408) 555-0255', isPrimary: false },
        { name: 'Dr. Helen Tran', relation: 'Geriatrician', phone: '(408) 555-3300', isPrimary: false }
      ],
      careTeam: [
        { name: 'Dr. Helen Tran', role: 'Geriatrician', organization: 'Stanford Geriatrics', phone: '(408) 555-3300' },
        { name: 'Priya Nair', role: 'Dementia Care Specialist', organization: 'CareBridge', phone: '(312) 555-0033' },
        { name: 'Dr. Kevin Marsh', role: 'Endocrinologist', organization: 'Valley Endocrine', phone: '(408) 555-7710' },
        { name: 'Rachel Obi', role: 'Occupational Therapist', organization: 'Bay Area OT', phone: '(408) 555-0441' }
      ],
      meds: [
        { name: 'Donepezil',    dosage: '10mg',     frequency: 'Once at night',  instructions: 'Take at bedtime to reduce nausea' },
        { name: 'Memantine',    dosage: '10mg',     frequency: 'Twice daily',    instructions: 'Take with or without food' },
        { name: 'Metformin',    dosage: '500mg',    frequency: 'Twice daily',    instructions: 'Take with meals' },
        { name: 'Alendronate',  dosage: '70mg',     frequency: 'Once weekly',    instructions: 'Take on empty stomach Monday; stand/sit upright for 30 min' }
      ],
      checkins: [
        { energy:6, mood:7, pain:3, fatigue:5, appetite:7, hydration:6, notes:'Recognised daughter and grandchild on video call – family delighted' },
        { energy:7, mood:8, pain:2, fatigue:4, appetite:8, hydration:7, notes:'Excellent morning; participated in music therapy group, sang along' },
        { energy:5, mood:5, pain:3, fatigue:6, appetite:6, hydration:5, notes:'Mild confusion in the afternoon; redirected successfully with familiar photos' },
        { energy:6, mood:6, pain:3, fatigue:5, appetite:7, hydration:6, notes:'Blood glucose 112 mg/dL – best reading this week' },
        { energy:7, mood:7, pain:2, fatigue:4, appetite:7, hydration:7, notes:'Engaged in afternoon gardening activity; identified rose bush correctly' },
        { energy:5, mood:4, pain:4, fatigue:7, appetite:5, hydration:5, notes:'Sundowning episode at 5pm; took 45 min to settle with reassurance' },
        { energy:6, mood:7, pain:2, fatigue:5, appetite:7, hydration:7, notes:'Very settled day; completed simple puzzle with caregiver supervision' }
      ],
      notes: [
        { cg: 'cg1', type: 'observation',   content: 'Moderate sundowning episodes 3x this week between 5-7pm. Dimmer lighting and favourite music routine being trialled to reduce agitation.' },
        { cg: 'cg3', type: 'behavior',      content: 'Dorothy became distressed believing she needed to pick up children from school. Therapeutic fibbing technique used successfully to redirect.' },
        { cg: 'cg2', type: 'nutrition',     content: 'Finger foods introduced at lunch – greatly improved intake. Dorothy feeds herself more independently with smaller bite-sized items.' },
        { cg: 'cg1', type: 'observation',   content: 'No fall incidents this week. Non-slip socks and bed sensor working effectively. Family praised current fall prevention measures.' },
        { cg: 'cg3', type: 'communication', content: 'Long-term care planning meeting held with family. Daughter agreed to increase visit frequency to twice weekly for continuity.' },
        { cg: 'cg2', type: 'equipment',     content: 'Personal GPS tracker activated in pendant necklace. Dorothy accepted it as jewellery without difficulty.' }
      ]
    }
  ];


  const cgMap = { cg1: caregiverId, cg2: cg2Id, cg3: cg3Id };

  for (const p of demoPatients) {
    const ur = db.prepare(
      "INSERT OR IGNORE INTO users (email, password_hash, role, first_name, last_name) VALUES (?, ?, 'patient', ?, ?)"
    ).run(p.email, hash, p.firstName, p.lastName);

    let userId = ur.lastInsertRowid;
    if (!userId) {
      const u = db.prepare('SELECT id FROM users WHERE email = ?').get(p.email);
      userId = u?.id;
      if (!userId) continue;
    }

    if (db.prepare('SELECT id FROM patients WHERE user_id = ?').get(userId)) continue;

    const pr = db.prepare(`
      INSERT INTO patients
        (user_id, date_of_birth, diagnoses, allergies, wellness_score,
         gender, height_cm, weight_kg, hearing_notes, vision_score,
         emergency_contacts, care_team, medical_history,
         ai_companion_name, ai_companion_gender)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      userId, p.dob,
      JSON.stringify(p.diagnoses), JSON.stringify(p.allergies), p.score,
      p.gender ?? null, p.heightCm ?? null, p.weightKg ?? null,
      p.hearingNotes ?? null, p.visionScore ?? null,
      JSON.stringify(p.emergencyContacts ?? []),
      JSON.stringify(p.careTeam ?? []),
      p.medicalHistory ?? null,
      p.aiCompanionName ?? null, p.aiCompanionGender ?? null
    );
    const patientId = pr.lastInsertRowid;

    // Join code
    let code;
    do { code = generateCode(); } while (db.prepare('SELECT id FROM join_codes WHERE code = ?').get(code));
    db.prepare('INSERT INTO join_codes (code, patient_id) VALUES (?, ?)').run(code, patientId);

    for (const med of p.meds) {
      db.prepare('INSERT INTO medications (patient_id, name, dosage, frequency, instructions, is_active) VALUES (?, ?, ?, ?, ?, 1)')
        .run(patientId, med.name, med.dosage, med.frequency, med.instructions);
    }

    const baseDate = new Date();
    for (let i = p.checkins.length - 1; i >= 0; i--) {
      const w = p.checkins[i];
      const d = new Date(baseDate);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      db.prepare(`
        INSERT INTO wellness_checkins
          (patient_id, date, energy, mood, pain, fatigue, appetite, hydration, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(patientId, dateStr, w.energy, w.mood, w.pain, w.fatigue, w.appetite, w.hydration, w.notes);
    }

    for (const n of p.notes) {
      db.prepare('INSERT INTO care_notes (patient_id, caregiver_id, note_type, content) VALUES (?, ?, ?, ?)')
        .run(patientId, cgMap[n.cg], n.type, n.content);
    }
  }

  // ── Link demo family to Alice ─────────────────────────────────────────────
  const aliceUser    = db.prepare("SELECT id FROM users WHERE email = 'alice@carebridge.demo'").get();
  const alicePatient = aliceUser ? db.prepare('SELECT id FROM patients WHERE user_id = ?').get(aliceUser.id) : null;

  if (alicePatient) {
    let familyId;
    const ef = db.prepare("SELECT id FROM users WHERE email = 'family@demo.com'").get();
    if (ef) {
      familyId = ef.id;
    } else {
      familyId = db.prepare(
        "INSERT INTO users (email, password_hash, role, first_name, last_name) VALUES (?, ?, 'family', 'Demo', 'Family')"
      ).run('family@demo.com', hash).lastInsertRowid;
    }
    db.prepare('INSERT OR IGNORE INTO family_patient_links (family_user_id, patient_id) VALUES (?, ?)').run(familyId, alicePatient.id);
  }

  logger.info('✅ Demo data seeded — 6 patients, 3 caregivers, 1 linked family');
}
