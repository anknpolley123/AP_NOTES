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
    xl: 'w-32 h-32'
  };

  return (
    <div className={`relative flex flex-col items-center justify-center ${className}`}>
      <div className={`${sizes[size]} relative flex items-center justify-center`}>
        {/* Stylized Dragon Head Logo */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full text-red-500 drop-shadow-[0_0_15px_rgba(239,68,68,0.6)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="2.5"
        >
          {/* Dragon Head Silhouette */}
          <path 
            d="M25,45 C25,25 45,15 65,20 C75,22 85,30 85,45 C85,60 75,70 60,75 L30,80 Q20,80 20,65 L25,45" 
            fill="currentColor" 
            fillOpacity="0.2" 
          />
          {/* Eye */}
          <circle cx="65" cy="35" r="3" fill="currentColor" stroke="none" />
          {/* Horns/Spikes */}
          <path d="M50,18 L45,5 M60,18 L65,8" strokeWidth="2" />
          {/* Small flame coming from nose/mouth area at the front */}
          <path 
            d="M85,45 L98,48 M85,48 L94,52" 
            strokeWidth="3" 
            strokeLinecap="round" 
            className="animate-pulse text-orange-500" 
          />
          {/* Lower Jaw Detail */}
          <path d="M85,45 L75,55" opacity="0.6" />
        </svg>
        
        {/* AP Text */}
        <span className="relative z-10 font-black italic tracking-tighter text-white drop-shadow-lg" style={{ fontSize: size === 'xl' ? '2.5rem' : '1.2rem' }}>
          AP
        </span>
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
