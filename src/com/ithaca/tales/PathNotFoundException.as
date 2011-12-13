package com.ithaca.tales
{
public class PathNotFoundException extends Error
{
    public function PathNotFoundException(msg: String)
    {
        this.message = msg;
    }
}
}
