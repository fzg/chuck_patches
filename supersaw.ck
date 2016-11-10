// supersaw
// based on study by Adam Szabo
// https://www.nada.kth.se/utbildning/grukth/exjobb/rapportlistor/2010/rapporter10/szabo_adam_10131.pdf

// TODO:
//  handle midi messages


// computer key input, with sound
KBHit kb;

class supersaw {
   static Gain   @c[6];  // six channel mixer [todo, curves]
   static SawOsc @o[6];  // six sawtooth oscs
   static HPF    @f[6];  // six hpfs
   new Gain[6]   @=> c;
   new HPF[6]    @=> f;
   new SawOsc[6] @=> o;
   Detune xd;
   ADSR env;
   float mixcontrol;

   0.9 => xd.amount;		// initial amount of detuning
   1 => mixcontrol;		// initial oscillator mixing
   for(0 =>int i; i < 6; ++i) {
     o[i] => f[i] => c[i] => env => dac;
     setMixLevel(i);
   }

   // computes the detuned frequency for each osc
   [ - 0.11002313,  - 0.06288439,- 0.01952356, 0.01991221,0.06216538,0.10745242] @=> float osc_offsets[];
   fun float dodetune(float x, int n) {
     if (n == 0)return x;
     //<<<  xd.output() >>>;
     return x+(osc_offsets[n-1] * 1 + xd.output());
   }

   // returns a random phase
   fun float randphase() {
     return Std.rand2f(-Math.PI / 2.0, Math.PI / 2.0);
   }

   // Mixes: main osc gain decreases linearly, 6 others' increase parabolically
   fun void setMixLevel(int i) {
     if (i == 0) -0.55366*mixcontrol + 0.99785 => c[i].gain;
     else -0.73764*mixcontrol*mixcontrol + 1.2841*mixcontrol + 0.044372 => c[i].gain;
   }

   fun void trigger(float freq) {
     1 => env.keyOn;
     env.set(.1::second,1::second,0.0,.1::second);

     for(0 =>int i; i < 6; ++i) {
       randphase()   => o[i].phase;
       dodetune(freq,i) => o[i].freq;
       freq * 2 => f[i].freq;               // adjust HPF
     }
   }

   fun void setMixLevels() {
     for(0 =>int i; i < 6; ++i) {
       setMixLevel(i);
     }
   }
}

// ------------------- Polypoly -------------------


public class supersaws {
   16 => int nosc;
   supersaw @s[nosc];
   new supersaw[nosc]    @=> s;

   fun void trigger(float f) {
     for(0=>int i; i<nosc;++i) {
      s[i].trigger(f);
     }
   }
}


// ------------------- RUN LOOP -------------------

supersaws s;
// TODO: use midi for keys, ud/lr for detune/mix
//  see examples/midi/polyfony.ck
//  on blahevent -> setMixLevels

while( true ) {
    // wait on event
    kb => now;

    while( kb.more() ) {
        kb.getchar() => int c => Std.mtof => float f;
        s.trigger(f);
    }
}
