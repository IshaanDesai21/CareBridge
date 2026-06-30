import dotenv from 'dotenv';
import { connectDatabase } from './connection.js';
import seed from './seed.js';

dotenv.config();

async function migrate() {
  try {
    console.log('🔄 Running database migrations...');
    
    // Connect to database (this also creates tables)
    await connectDatabase();
    
    console.log('✅ Migrations completed successfully!');
    console.log('');
    
    // Ask if user wants to seed
    const args = process.argv.slice(2);
    if (args.includes('--seed')) {
      console.log('🌱 Seeding database...');
      await seed();
    } else {
      console.log('To seed the database with sample data, run:');
      console.log('  npm run db:seed');
      console.log('');
      process.exit(0);
    }
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

migrate();
