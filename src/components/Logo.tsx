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
        {/* Futuristic Dragon Emblem */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full drop-shadow-[0_0_20px_rgba(239,68,68,0.5)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="3"
        >
          {/* Aerodynamic Dragon Head */}
          <path 
            d="M15,50 C15,20 45,15 65,22 Q85,28 90,45 T70,75 L25,85 Q15,85 15,65 Z" 
            className="text-red-600" 
            fill="currentColor" 
            fillOpacity="0.25" 
          />
          {/* Carbon Fiber Horns */}
          <path d="M48,18 L45,4 M60,20 L65,8" className="text-red-500" strokeWidth="4" strokeLinecap="round" />
          {/* Cyber Eye */}
          <circle cx="68" cy="40" r="2" fill="white" className="animate-pulse" />
          
          {/* Plasma Flare */}
          <path 
            d="M90,45 L100,48 M90,48 L98,54" 
            strokeWidth="4" 
            strokeLinecap="round" 
            className="text-orange-500 animate-pulse" 
          />
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
