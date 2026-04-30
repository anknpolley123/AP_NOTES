import React from 'react';

interface LogoProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

export default function Logo({ className = '', size = 'md' }: LogoProps) {
  const sizes = {
    sm: 'w-8 h-8',
    md: 'w-12 h-12',
    lg: 'w-24 h-24',
    xl: 'w-36 h-36'
  };

  return (
    <div className={`relative flex flex-col items-center justify-center ${className}`}>
      <div className={`${sizes[size]} relative flex items-center justify-center`}>
        {/* Stylized Modern Dragon Head Logo */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full drop-shadow-[0_0_20px_rgba(239,68,68,0.5)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="2.5"
        >
          {/* Main Head Contour - More Sleek */}
          <path 
            d="M15,50 C15,20 40,15 60,20 Q85,25 90,45 Q95,65 70,75 L25,85 Q15,85 15,65 L15,50" 
            className="text-red-600" 
            fill="currentColor" 
            fillOpacity="0.2" 
          />
          {/* Sharp Horns */}
          <path d="M45,18 L40,5 M55,20 L60,8" className="text-red-500" strokeWidth="3" strokeLinecap="round" />
          {/* Glowing Eye */}
          <circle cx="65" cy="38" r="2.5" fill="white" className="animate-pulse shadow-white shadow-sm" />
          {/* Flame from nostrils */}
          <path 
            d="M90,45 L100,48 M90,50 L98,55" 
            strokeWidth="3.5" 
            strokeLinecap="round" 
            className="text-orange-500 animate-flicker" 
          />
          <style>{`
            @keyframes flicker {
              0%, 100% { opacity: 1; transform: scale(1); }
              50% { opacity: 0.6; transform: scale(0.9); }
            }
            .animate-flicker { animation: flicker 0.2s infinite; }
          `}</style>
        </svg>

        
        {/* AP Text - Bold & Futuristic */}
        <div className="relative z-10 flex items-center justify-center pointer-events-none">
          <span className="font-black italic tracking-tighter text-white text-shadow-xl" style={{ fontSize: size === 'xl' ? '2.8rem' : '1.3rem' }}>
            AP
          </span>
        </div>
      </div>
      
      {size === 'xl' && (
        <div className="mt-4">
          <div className="text-[24px] font-black text-white italic tracking-tighter uppercase">AP_NOTES</div>
          <div className="text-[8px] font-black text-blue-500 tracking-[0.6em] uppercase opacity-60 text-center">Neural Workspace</div>
        </div>
      )}
    </div>
  );
}
