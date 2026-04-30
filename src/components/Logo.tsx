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
        {/* Stylised Dragon Path */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.4)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="3" 
          strokeLinecap="round" 
          strokeLinejoin="round"
        >
          {/* Dragon Head */}
          <path d="M70,30 C80,30 85,40 85,50 C85,60 75,65 65,65 L40,65 C30,65 20,55 20,40 C20,25 30,15 45,15 C60,15 70,25 70,30 Z" fill="currentColor" fillOpacity="0.1" />
          <path d="M85,50 L95,55" strokeWidth="4" className="animate-pulse" /> {/* Flame */}
          <path d="M20,40 Q15,60 30,80 Q45,100 70,85" /> {/* Dragon Tail */}
        </svg>
        
        {/* AP Text */}
        <span className="relative z-10 font-black italic tracking-tighter text-white" style={{ fontSize: size === 'xl' ? '2.5rem' : '1.2rem' }}>
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
