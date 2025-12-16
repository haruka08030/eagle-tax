import { corsHeaders } from './cors.ts';

export const errorResponse = (message: string, status = 500, extra: Record<string, any> = {}) => {
    return new Response(
        JSON.stringify({ error: message, ...extra }),
        {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status,
        }
    );
};

export const successResponse = (data: Record<string, any>, status = 200) => {
    return new Response(
        JSON.stringify(data),
        {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status,
        }
    );
};
